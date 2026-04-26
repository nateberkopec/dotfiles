require "test_helper"

class ProtectFilesStepTest < StepTestCase
  step_class Dotfiles::Step::ProtectFilesStep

  def setup
    super
    @fake_system.stub_macos
    @pi_extension_files = step.send(:pi_extension_files)
    @credentials_files = step.send(:user_credentials_files)
  end

  def test_run_protects_pi_extension_files
    @pi_extension_files.each { |file| @fake_system.stub_file_content(file, "extension content") }

    step.run

    @pi_extension_files.each do |file|
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

    @pi_extension_files.each do |file|
      refute_executed("sudo chflags schg '#{file}'", quiet: false)
    end
    check_credentials_files_protection(:refute)
  end

  def test_complete_when_all_files_are_protected
    @pi_extension_files.each do |file|
      @fake_system.stub_file_content(file, "extension content")
      stub_immutable(file, "schg")
    end
    stub_credentials_files(stat: "600", ls: "-rw------- uchg")

    assert_complete
  end

  def test_complete_clears_run_errors_when_files_are_now_protected
    @pi_extension_files.each { |file| @fake_system.stub_file_content(file, "extension content") }
    @fake_system.stub_command("sudo chflags schg '#{@pi_extension_files.first}'", "", 1)

    step.run

    refute_empty step.errors

    @pi_extension_files.each { |file| stub_immutable(file, "schg") }
    stub_credentials_files(stat: "600", ls: "-rw------- uchg")

    assert step.complete?
    assert_empty step.errors
  end

  def test_incomplete_when_pi_extension_file_is_not_immutable
    file = @pi_extension_files.first
    @fake_system.stub_file_content(file, "extension content")
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
    @pi_extension_files.each do |file|
      @fake_system.stub_file_content(file, "extension content")
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
