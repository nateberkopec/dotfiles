require "test_helper"

class DisableDisplaysHaveSpacesStepTest < Minitest::Test
  def test_runs_defaults_write_command
    step = create_step(Dotfiles::Step::DisableDisplaysHaveSpacesStep)
    step.run

    assert @fake_system.received_operation?(:execute, "defaults write com.apple.spaces spans-displays -bool true && killall SystemUIServer", {quiet: true, capture_output: false})
  end

  def test_complete_when_setting_matches
    @fake_system.stub_command_output("defaults read com.apple.spaces spans-displays", "1", exit_status: 0)

    step = create_step(Dotfiles::Step::DisableDisplaysHaveSpacesStep)
    assert step.complete?
  end

  def test_incomplete_when_setting_differs
    @fake_system.stub_command_output("defaults read com.apple.spaces spans-displays", "0", exit_status: 0)

    step = create_step(Dotfiles::Step::DisableDisplaysHaveSpacesStep)
    refute step.complete?
  end

  def test_incomplete_when_command_fails
    @fake_system.stub_command_output("defaults read com.apple.spaces spans-displays", "", exit_status: 1)

    step = create_step(Dotfiles::Step::DisableDisplaysHaveSpacesStep)
    refute step.complete?
  end
end
