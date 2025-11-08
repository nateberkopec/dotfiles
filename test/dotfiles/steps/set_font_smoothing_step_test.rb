require "test_helper"

class SetFontSmoothingStepTest < Minitest::Test
  def test_runs_defaults_write_command
    step = create_step(Dotfiles::Step::SetFontSmoothingStep)
    step.run

    assert @fake_system.received_operation?(:execute, "defaults -currentHost write -g AppleFontSmoothing -int 0", {quiet: true})
  end

  def test_complete_when_setting_is_zero
    @fake_system.stub_command("defaults -currentHost read -g AppleFontSmoothing", "0", exit_status: 0)

    step = create_step(Dotfiles::Step::SetFontSmoothingStep)
    assert step.complete?
  end

  def test_incomplete_when_setting_differs
    @fake_system.stub_command("defaults -currentHost read -g AppleFontSmoothing", "1", exit_status: 0)

    step = create_step(Dotfiles::Step::SetFontSmoothingStep)
    refute step.complete?
  end
end
