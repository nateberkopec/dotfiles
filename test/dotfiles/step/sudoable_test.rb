require "test_helper"

class SudoableTest < StepTestCase
  step_class Dotfiles::Step::SetFishDefaultShellStep

  def setup
    super
    @fake_system.stub_macos
    @fake_system.stub_file_content("/usr/bin/fish", "fish")
  end

  def test_skips_admin_warning_when_sudo_credentials_are_cached
    @fake_system.stub_command(["sudo", "-n", "-v"], "", 0)

    step.run

    refute admin_warning_displayed?
  end

  def test_displays_admin_warning_when_sudo_will_prompt
    @fake_system.stub_command(["sudo", "-n", "-v"], "sudo: a password is required", 1)

    step.run

    assert admin_warning_displayed?
  end

  def test_skips_admin_warning_when_sudo_validation_fails_for_another_reason
    @fake_system.stub_command(["sudo", "-n", "-v"], "sudo: command not found", 127)

    step.run

    refute admin_warning_displayed?
  end

  private

  def admin_warning_displayed?
    @fake_system.operations.any? do |operation, command, _options|
      operation == :execute && command.include?("🔒 Admin Privileges Required")
    end
  end
end
