require "test_helper"

class InstallYknotifyStepTest < StepTestCase
  step_class Dotfiles::Step::InstallYknotifyStep

  def test_should_run_when_yknotify_not_installed
    stub_yknotify_missing
    assert_should_run
  end

  def test_should_run_when_launchagent_missing
    stub_yknotify_on_path
    assert_should_run
  end

  def test_should_not_run_when_fully_installed
    stub_yknotify_on_path
    @fake_system.write_file(launchagent_path, "")
    refute_should_run
  end

  def test_run_installs_go_package_when_missing
    stub_yknotify_missing
    stub_power_issue_open
    step.run

    assert_executed("mise use -g go@latest")
    assert_executed("git clone -b predicate-filter --depth 1 https://github.com/nateberkopec/yknotify.git /tmp/yknotify-build")
    assert_executed("cd /tmp/yknotify-build && mise exec -- go install .")
    assert_executed("rm -rf /tmp/yknotify-build")
  end

  def test_run_skips_go_install_when_yknotify_exists
    stub_yknotify_on_path
    step.run

    refute_executed("git clone -b predicate-filter --depth 1 https://github.com/nateberkopec/yknotify.git /tmp/yknotify-build")
  end

  def test_run_installs_script_to_xdg_data_dir
    step.run

    assert_command_run(:mkdir_p, script_dir)
    assert_command_run(:chmod, 0o755, script_path)
    assert @fake_system.file_exist?(script_path)
  end

  def test_run_installs_launchagent
    step.run

    assert_command_run(:mkdir_p, File.dirname(launchagent_path))
    assert @fake_system.file_exist?(launchagent_path)
  end

  def test_run_loads_launchagent
    step.run

    assert_executed("launchctl unload #{launchagent_path} 2>/dev/null || true")
    assert_executed("launchctl load #{launchagent_path}")
  end

  def test_script_contains_correct_paths
    stub_mise_which_yknotify
    step.run

    content = @fake_system.read_file(script_path)
    assert_includes content, "#{@home}/.local/share/mise/installs/go/latest/bin/yknotify"
    assert_includes content, "/opt/homebrew/bin/terminal-notifier"
  end

  def test_plist_references_xdg_script_path
    step.run

    content = @fake_system.read_file(launchagent_path)
    assert_includes content, script_path
  end

  def test_complete_when_all_installed
    stub_yknotify_on_path
    stub_terminal_notifier_on_path
    @fake_system.write_file(launchagent_path, "")

    assert_complete
  end

  def test_incomplete_when_yknotify_missing
    stub_yknotify_missing
    stub_terminal_notifier_on_path
    @fake_system.write_file(launchagent_path, "")

    assert_incomplete
  end

  def test_incomplete_when_terminal_notifier_missing
    stub_yknotify_on_path
    stub_terminal_notifier_missing
    @fake_system.write_file(launchagent_path, "")

    assert_incomplete
  end

  def test_incomplete_when_launchagent_missing
    stub_yknotify_on_path
    stub_terminal_notifier_on_path

    assert_incomplete
  end

  private

  def stub_yknotify_on_path
    @fake_system.stub_command("command -v yknotify >/dev/null 2>&1", "", 0)
  end

  def stub_yknotify_missing
    @fake_system.stub_command("command -v yknotify >/dev/null 2>&1", "", 1)
    @fake_system.stub_command("mise which yknotify", "", 1)
  end

  def stub_terminal_notifier_on_path
    @fake_system.stub_command("command -v terminal-notifier >/dev/null 2>&1", "", 0)
  end

  def stub_terminal_notifier_missing
    @fake_system.stub_command("command -v terminal-notifier >/dev/null 2>&1", "", 1)
  end

  def stub_mise_which_yknotify
    @fake_system.stub_command("mise which yknotify", "#{@home}/.local/share/mise/installs/go/latest/bin/yknotify", 0)
  end

  def stub_power_issue_open
    @fake_system.stub_command("gh issue view 7 -R noperator/yknotify --json state -q '.state'", "OPEN", 0)
  end

  def script_dir
    File.join(@home, ".local/share/yknotify")
  end

  def script_path
    File.join(script_dir, "yknotify.sh")
  end

  def launchagent_path
    File.join(@home, "Library/LaunchAgents/com.user.yknotify.plist")
  end
end
