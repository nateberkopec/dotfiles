require "test_helper"

class SetFishDefaultShellStepTest < Minitest::Test
  def setup
    super
    @fake_system.stub_macos
    @step = create_step(Dotfiles::Step::SetFishDefaultShellStep)
  end

  def test_complete_when_fish_is_default_shell
    @fake_system.stub_command("command -v fish 2>/dev/null", "/opt/homebrew/bin/fish\n")
    @fake_system.stub_command("dscl . -read ~/ UserShell", "UserShell: /opt/homebrew/bin/fish")

    assert @step.complete?
  end

  def test_incomplete_when_different_shell
    @fake_system.stub_command("command -v fish 2>/dev/null", "/opt/homebrew/bin/fish\n")
    @fake_system.stub_command("dscl . -read ~/ UserShell", "UserShell: /bin/zsh")

    refute @step.complete?
  end

  def test_complete_returns_true_in_ci
    stub_shell_mismatch
    with_ci { assert @step.complete? }
  end

  def test_complete_returns_true_in_noninteractive
    stub_shell_mismatch
    with_env("NONINTERACTIVE" => "true") { assert @step.complete? }
  end

  def test_rechecks_fish_path_after_initial_miss
    @fake_system.stub_command("command -v fish 2>/dev/null", "", exit_status: 1)
    @fake_system.stub_command("dscl . -read ~/ UserShell", "UserShell: /usr/bin/fish")

    refute @step.complete?

    @fake_system.stub_file_content("/usr/bin/fish", "")
    assert @step.complete?
  end

  private

  def stub_shell_mismatch
    @fake_system.stub_command("command -v fish 2>/dev/null", "/opt/homebrew/bin/fish\n")
    @fake_system.stub_command("dscl . -read ~/ UserShell", "UserShell: /bin/zsh")
  end
end
