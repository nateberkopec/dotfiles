require "test_helper"

class UpdateHomebrewStepTest < StepTestCase
  step_class Dotfiles::Step::UpdateHomebrewStep

  def test_runs_brew_update
    step.run
    assert_executed("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew update 2>&1")
  end

  def test_always_complete
    assert_complete
  end
end
