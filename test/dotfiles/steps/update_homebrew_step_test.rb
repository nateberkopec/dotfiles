require "test_helper"

class UpdateHomebrewStepTest < Minitest::Test
  def test_runs_brew_update
    step = create_step(Dotfiles::Step::UpdateHomebrewStep)
    step.run

    assert @fake_system.received_operation?(:execute, "HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew update 2>&1", {quiet: true})
  end

  def test_always_complete
    step = create_step(Dotfiles::Step::UpdateHomebrewStep)
    assert step.complete?
  end
end
