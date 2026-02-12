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

  def test_run_falls_back_to_usermod_when_chsh_does_not_change_shell
    @fake_system.stub_macos(false)
    @fake_system.stub_debian
    @fake_system.stub_running_container
    @fake_system.stub_file_content("/etc/shells", "/usr/bin/fish\n")

    @fake_system.stub_command("command -v fish 2>/dev/null", "/usr/bin/fish\n")
    @fake_system.stub_command("id -un", "runner\n")
    @fake_system.stub_command("id -u", "1000\n")
    @fake_system.stub_command("getent passwd 1000", "runner:x:1000:1000::/home/runner:/bin/bash")
    @fake_system.stub_command("chsh -s /usr/bin/fish runner", "")
    @fake_system.stub_command("sudo usermod --shell /usr/bin/fish runner", "")

    @step.run

    assert @fake_system.received_operation?(:execute, "sudo usermod --shell /usr/bin/fish runner", {quiet: false})
  end

  private

  def stub_shell_mismatch
    @fake_system.stub_command("command -v fish 2>/dev/null", "/opt/homebrew/bin/fish\n")
    @fake_system.stub_command("dscl . -read ~/ UserShell", "UserShell: /bin/zsh")
  end
end
