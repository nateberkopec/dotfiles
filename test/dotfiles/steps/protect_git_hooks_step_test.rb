require "test_helper"

class ProtectGitHooksStepTest < StepTestCase
  step_class Dotfiles::Step::ProtectGitHooksStep

  def setup
    super
    @hook_file = File.join(@home, ".git-hooks", "pre-push")
  end

  def test_run_protects_hook_file
    @fake_system.filesystem[@hook_file] = "hook content"
    step.run

    assert_executed("sudo chflags schg '#{@hook_file}'", quiet: false)
  end

  def test_run_skips_missing_hook_file
    step.run
    refute_executed("sudo chflags schg '#{@hook_file}'", quiet: false)
  end

  def test_complete_when_hook_file_is_immutable
    @fake_system.filesystem[@hook_file] = "hook content"
    stub_immutable(@hook_file, true)
    assert_complete
  end

  def test_incomplete_when_hook_file_is_not_immutable
    @fake_system.filesystem[@hook_file] = "hook content"
    stub_immutable(@hook_file, false)
    assert_incomplete
  end

  def test_complete_when_hook_file_does_not_exist
    assert_complete
  end

  def test_complete_in_ci
    @fake_system.filesystem[@hook_file] = "hook content"
    stub_immutable(@hook_file, false)
    ENV["CI"] = "true"
    assert_complete
  ensure
    ENV.delete("CI")
  end

  private

  def stub_immutable(file, immutable)
    output = immutable ? "-rw-r--r-- schg" : "-rw-r--r--"
    @fake_system.stub_command("ls -lO '#{file}'", output)
  end
end
