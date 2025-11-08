require "test_helper"

class SetFontSmoothingStepTest < StepTestCase
  step_class Dotfiles::Step::SetFontSmoothingStep

  def test_runs_defaults_write_command
    step.run
    assert_executed("defaults -currentHost write -g AppleFontSmoothing -int 0")
  end

  def test_complete_when_setting_is_zero
    @fake_system.stub_command("defaults -currentHost read -g AppleFontSmoothing", "0", exit_status: 0)
    assert_complete
  end

  def test_incomplete_when_setting_differs
    @fake_system.stub_command("defaults -currentHost read -g AppleFontSmoothing", "1", exit_status: 0)
    assert_incomplete
  end
end
