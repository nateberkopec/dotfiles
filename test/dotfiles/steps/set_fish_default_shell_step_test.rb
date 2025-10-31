require "test_helper"

class SetFishDefaultShellStepTest < Minitest::Test
  def setup
    super
    @step = create_step(Dotfiles::Step::SetFishDefaultShellStep)
  end

  def test_complete_returns_boolean_by_default
    result = @step.complete?
    assert [true, false].include?(result)
  end

  def test_complete_when_fish_is_default_shell
    @fake_system.stub_command_output("which fish", "/opt/homebrew/bin/fish\n")
    @fake_system.stub_command_output("dscl . -read ~/ UserShell", "UserShell: /opt/homebrew/bin/fish")

    assert @step.complete?
  end

  def test_incomplete_when_different_shell
    @fake_system.stub_command_output("which fish", "/opt/homebrew/bin/fish\n")
    @fake_system.stub_command_output("dscl . -read ~/ UserShell", "UserShell: /bin/zsh")

    refute @step.complete?
  end

  def test_complete_returns_true_in_ci
    ENV["CI"] = "true"
    assert @step.complete?
  ensure
    ENV.delete("CI")
  end

  def test_complete_returns_true_in_noninteractive
    ENV["NONINTERACTIVE"] = "true"
    assert @step.complete?
  ensure
    ENV.delete("NONINTERACTIVE")
  end
end
