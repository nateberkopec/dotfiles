require "test_helper"

class UpdateMacOSStepTest < Minitest::Test
  def test_should_run_returns_false
    step = create_step(Dotfiles::Step::UpdateMacOSStep)
    refute step.should_run?
  end

  def test_step_exists
    step = create_step(Dotfiles::Step::UpdateMacOSStep)
    assert_instance_of Dotfiles::Step::UpdateMacOSStep, step
  end

  def test_complete_returns_true
    step = create_step(Dotfiles::Step::UpdateMacOSStep)
    assert step.complete?
  end
end
