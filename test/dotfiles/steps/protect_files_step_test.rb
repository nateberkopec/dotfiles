require "test_helper"

class ProtectFilesStepTest < StepTestCase
  step_class Dotfiles::Step::ProtectFilesStep

  def setup
    super
    @fake_system.stub_macos
    @hook_files = step.send(:agent_hook_files)
    @credentials_files = step.send(:user_credentials_files)
  end

  def test_run_protects_hook_files
    @hook_files.each { |file| @fake_system.stub_file_content(file, "hook content") }

    step.run

    @hook_files.each do |file|
      assert_executed("sudo chflags schg '#{file}'", quiet: false)
      refute_command_run(:chmod, 0o600, file)
    end
  end

  def test_run_protects_credentials_files
    @credentials_files.each { |file| @fake_system.stub_file_content(file, "stub") }

    step.run

    check_credentials_files_protection(:assert)
  end

  def test_run_skips_missing_files
    step.run

    @hook_files.each do |file|
      refute_executed("sudo chflags schg '#{file}'", quiet: false)
    end
    check_credentials_files_protection(:refute)
  end

  def test_run_skips_already_protected_files
    file = @credentials_files.first
    stub_credentials_file(file, stat: "600", ls: "-rw------- uchg")

    step.run

    refute_command_run(:chmod, 0o600, file)
    refute_executed("chflags uchg '#{file}'", quiet: false)
  end

  def test_complete_when_all_files_are_protected
    @hook_files.each do |file|
      @fake_system.stub_file_content(file, "hook content")
      stub_immutable(file, "schg")
    end
    stub_credentials_files(stat: "600", ls: "-rw------- uchg")

    assert_complete
  end

  def test_complete_clears_run_errors_when_files_are_now_protected
    @hook_files.each { |file| @fake_system.stub_file_content(file, "hook content") }
    @fake_system.stub_command("sudo chflags schg '#{@hook_files.first}'", "", 1)

    step.run

    refute_empty step.errors

    @hook_files.each { |file| stub_immutable(file, "schg") }
    stub_credentials_files(stat: "600", ls: "-rw------- uchg")

    assert step.complete?
    assert_empty step.errors
  end

  def test_incomplete_when_hook_file_is_not_immutable
    file = @hook_files.first
    @fake_system.stub_file_content(file, "hook content")
    stub_immutable(file, nil)

    assert_incomplete
  end

  def test_incomplete_when_credentials_permissions_are_too_open
    stub_credentials_file(@credentials_files.first, stat: "644", ls: "-rw-r--r-- uchg")

    assert_incomplete
  end

  def test_complete_when_files_do_not_exist
    assert_complete
  end

  def test_complete_in_ci
    @hook_files.each do |file|
      @fake_system.stub_file_content(file, "hook content")
    end
    @credentials_files.each { |file| @fake_system.stub_file_content(file, "stub") }

    with_ci { assert_complete }
  end

  private

  def check_credentials_files_protection(assertion)
    @credentials_files.each do |file|
      send(:"#{assertion}_command_run", :chmod, 0o600, file)
      send(:"#{assertion}_executed", "chflags uchg '#{file}'", quiet: false)
    end
  end

  def stub_immutable(file, flag)
    output = ["-rw-r--r--", flag].compact.join(" ")
    @fake_system.stub_command("ls -lO '#{file}'", output)
  end

  def stub_credentials_files(stat:, ls:)
    @credentials_files.each { |file| stub_credentials_file(file, stat: stat, ls: ls) }
  end

  def stub_credentials_file(file, stat:, ls:)
    @fake_system.stub_file_content(file, "stub")
    @fake_system.stub_command("stat -f '%Lp' '#{file}'", stat)
    @fake_system.stub_command("ls -lO '#{file}'", ls)
  end
end
