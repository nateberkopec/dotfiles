require "test_helper"

class ProtectGitHooksStepTest < StepTestCase
  step_class Dotfiles::Step::ProtectGitHooksStep

  def setup
    super
    @hook_files = [
      File.join(@home, ".git-hooks", "pre-commit"),
      File.join(@home, ".git-hooks", "pre-push")
    ]
  end

  def test_run_protects_hook_files
    @hook_files.each { |file| @fake_system.filesystem[file] = "hook content" }
    step.run

    @hook_files.each do |file|
      assert_executed("sudo chflags schg '#{file}'", quiet: false)
    end
  end

  def test_run_skips_missing_hook_files
    step.run
    @hook_files.each do |file|
      refute_executed("sudo chflags schg '#{file}'", quiet: false)
    end
  end

  def test_complete_when_hook_files_are_immutable
    @hook_files.each do |file|
      @fake_system.filesystem[file] = "hook content"
      stub_immutable(file, true)
    end
    assert_complete
  end

  def test_incomplete_when_hook_file_is_not_immutable
    file = @hook_files.first
    @fake_system.filesystem[file] = "hook content"
    stub_immutable(file, false)
    assert_incomplete
  end

  def test_complete_when_hook_file_does_not_exist
    assert_complete
  end

  def test_complete_in_ci
    file = @hook_files.first
    @fake_system.filesystem[file] = "hook content"
    stub_immutable(file, false)
    with_ci { assert_complete }
  end

  private

  def stub_immutable(file, immutable)
    output = immutable ? "-rw-r--r-- schg" : "-rw-r--r--"
    @fake_system.stub_command("ls -lO '#{file}'", output)
  end
end
