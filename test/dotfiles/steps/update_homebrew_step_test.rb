require "test_helper"

class UpdateHomebrewStepTest < StepTestCase
  step_class Dotfiles::Step::UpdateHomebrewStep

  def test_depends_on_install_homebrew
    assert_includes Dotfiles::Step::UpdateHomebrewStep.depends_on, Dotfiles::Step::InstallHomebrewStep
  end

  def test_runs_brew_update
    step.run
    assert_executed("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew update 2>&1")
  end

  def test_always_complete
    assert_complete
  end

  def test_should_not_run
    refute_should_run
  end

  def test_complete_after_errors
    step.add_error("Test error")
    assert_complete
    assert_empty step.errors
  end
end
