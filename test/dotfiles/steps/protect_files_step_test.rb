require "test_helper"

class ProtectFilesStepTest < StepTestCase
  step_class Dotfiles::Step::ProtectFilesStep

  def setup
    super
    @fake_system.stub_macos
    @hook_files = step.send(:agent_hook_files)
    @credentials_file = step.send(:gem_credentials_file)
  end

  def test_run_protects_hook_files
    @hook_files.each { |file| @fake_system.stub_file_content(file, "hook content") }

    step.run

    @hook_files.each do |file|
      assert_executed("sudo chflags schg '#{file}'", quiet: false)
      refute_command_run(:chmod, 0o600, file)
    end
  end

  def test_run_protects_credentials_file
    @fake_system.stub_file_content(@credentials_file, "stub")

    step.run

    assert_command_run(:chmod, 0o600, @credentials_file)
    assert_executed("chflags uchg '#{@credentials_file}'", quiet: false)
  end

  def test_run_skips_missing_files
    step.run

    @hook_files.each do |file|
      refute_executed("sudo chflags schg '#{file}'", quiet: false)
    end
    refute_command_run(:chmod, 0o600, @credentials_file)
    refute_executed("chflags uchg '#{@credentials_file}'", quiet: false)
  end

  def test_complete_when_all_files_are_protected
    @hook_files.each do |file|
      @fake_system.stub_file_content(file, "hook content")
      stub_immutable(file, "schg")
    end
    stub_credentials_file(stat: "600", ls: "-rw------- uchg")

    assert_complete
  end

  def test_incomplete_when_hook_file_is_not_immutable
    file = @hook_files.first
    @fake_system.stub_file_content(file, "hook content")
    stub_immutable(file, nil)

    assert_incomplete
  end

  def test_incomplete_when_credentials_permissions_are_too_open
    stub_credentials_file(stat: "644", ls: "-rw-r--r-- uchg")

    assert_incomplete
  end

  def test_complete_when_files_do_not_exist
    assert_complete
  end

  def test_complete_in_ci
    @hook_files.each do |file|
      @fake_system.stub_file_content(file, "hook content")
    end
    @fake_system.stub_file_content(@credentials_file, "stub")

    with_ci { assert_complete }
  end

  private

  def stub_immutable(file, flag)
    output = ["-rw-r--r--", flag].compact.join(" ")
    @fake_system.stub_command("ls -lO '#{file}'", output)
  end

  def stub_credentials_file(stat:, ls:)
    @fake_system.stub_file_content(@credentials_file, "stub")
    @fake_system.stub_command("stat -f '%Lp' '#{@credentials_file}'", stat)
    @fake_system.stub_command("ls -lO '#{@credentials_file}'", ls)
  end
end
