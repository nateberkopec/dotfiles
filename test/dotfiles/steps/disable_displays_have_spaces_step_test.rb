require "test_helper"

class DisableDisplaysHaveSpacesStepTest < StepTestCase
  step_class Dotfiles::Step::DisableDisplaysHaveSpacesStep

  def test_run_sets_preference_and_restarts_system_ui
    step.run
    assert_executed("defaults write com.apple.spaces spans-displays -bool true && killall SystemUIServer")
  end

  def test_complete_when_defaults_match
    stub_spans_displays("1")
    assert_complete
  end

  def test_incomplete_when_value_differs
    stub_spans_displays("0")
    assert_incomplete
  end

  def test_incomplete_when_command_fails
    stub_spans_displays("", status: 1)
    assert_incomplete
  end

  private

  def stub_spans_displays(value, status: 0)
    @fake_system.stub_command("defaults read com.apple.spaces spans-displays", value, exit_status: status)
  end
end
