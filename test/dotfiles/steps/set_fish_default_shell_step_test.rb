require "test_helper"

class SetFishDefaultShellStepTest < Minitest::Test
  def test_complete_when_fish_is_default_shell
    @fake_system.stub_command_output("which fish", "/opt/homebrew/bin/fish\n")
    @fake_system.stub_command_output("dscl . -read ~/ UserShell", "UserShell: /opt/homebrew/bin/fish")

    step = create_step(Dotfiles::Step::SetFishDefaultShellStep)
    assert step.complete?
  end

  def test_incomplete_when_different_shell
    @fake_system.stub_command_output("which fish", "/opt/homebrew/bin/fish\n")
    @fake_system.stub_command_output("dscl . -read ~/ UserShell", "UserShell: /bin/zsh")

    step = create_step(Dotfiles::Step::SetFishDefaultShellStep)
    refute step.complete?
  end
end
