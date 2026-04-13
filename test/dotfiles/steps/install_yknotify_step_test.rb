require "test_helper"

class InstallYknotifyStepTest < StepTestCase
  step_class Dotfiles::Step::InstallYknotifyStep

  def test_skips_in_ci
    @fake_system.stub_macos
    with_ci do
      refute step.should_run?
      assert step.complete?
    end
  end

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
    stub_launchagent_loaded
    install_current_files
    refute_should_run
  end

  def test_should_run_when_script_is_stale
    stub_yknotify_on_path
    install_current_files
    @fake_system.write_file(script_path, "#!/bin/bash\n")

    assert_should_run
  end

  def test_should_run_when_launchagent_is_stale
    stub_yknotify_on_path
    install_current_files
    @fake_system.write_file(launchagent_path, "<plist/>\n")

    assert_should_run
  end

  def test_should_run_when_launchagent_is_unloaded
    stub_yknotify_on_path
    stub_launchagent_unloaded
    install_current_files

    assert_should_run
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

    assert_executed("launchctl bootout gui/#{Process.uid} #{launchagent_path} 2>/dev/null || true")
    assert_executed("launchctl enable gui/#{Process.uid}/com.user.yknotify")
    assert_executed("launchctl bootstrap gui/#{Process.uid} #{launchagent_path}")
    assert_executed("launchctl kickstart -k gui/#{Process.uid}/com.user.yknotify")
  end

  def test_script_resolves_yknotify_at_runtime
    step.run

    content = @fake_system.read_file(script_path)
    assert_includes content, 'MISE_BIN="mise"'
    assert_includes content, 'YKNTFY_BIN="$($MISE_BIN which yknotify 2>/dev/null)"'
    assert_includes content, "#{@home}/.local/bin:#{@home}/.homebrew/bin:/opt/homebrew/bin"
    assert_includes content, 'TERM_NTFY_BIN="terminal-notifier"'
    assert_includes content, 'mkfifo "$TEMP_FIFO"'
    assert_includes content, 'kill "$YKNTFY_PID" 2>/dev/null || true'
  end

  def test_plist_references_xdg_script_path
    step.run

    content = @fake_system.read_file(launchagent_path)
    assert_includes content, script_path
  end

  def test_complete_when_all_installed
    stub_yknotify_on_path
    stub_terminal_notifier_on_path
    stub_launchagent_loaded
    install_current_files

    assert_complete
  end

  def test_incomplete_when_yknotify_missing
    stub_yknotify_missing
    stub_terminal_notifier_on_path
    stub_launchagent_loaded
    install_current_files

    assert_incomplete
  end

  def test_incomplete_when_terminal_notifier_missing
    stub_yknotify_on_path
    stub_terminal_notifier_missing
    stub_launchagent_loaded
    install_current_files

    assert_incomplete
  end

  def test_incomplete_when_script_missing
    stub_yknotify_on_path
    stub_terminal_notifier_on_path
    stub_launchagent_loaded
    @fake_system.write_file(launchagent_path, step.send(:plist_content))

    assert_incomplete
  end

  def test_incomplete_when_launchagent_missing
    stub_yknotify_on_path
    stub_terminal_notifier_on_path
    @fake_system.write_file(script_path, step.send(:script_content))

    assert_incomplete
  end

  def test_incomplete_when_launchagent_unloaded
    stub_yknotify_on_path
    stub_terminal_notifier_on_path
    stub_launchagent_unloaded
    install_current_files

    assert_incomplete
  end

  private

  def stub_yknotify_on_path
    @fake_system.stub_command("command -v yknotify >/dev/null 2>&1", "", 0)
  end

  def stub_yknotify_missing
    @fake_system.stub_command("command -v yknotify >/dev/null 2>&1", "", 1)
  end

  def stub_terminal_notifier_on_path
    @fake_system.stub_command("command -v terminal-notifier >/dev/null 2>&1", "", 0)
  end

  def stub_terminal_notifier_missing
    @fake_system.stub_command("command -v terminal-notifier >/dev/null 2>&1", "", 1)
  end

  def stub_launchagent_loaded
    @fake_system.stub_command("launchctl print gui/#{Process.uid}/com.user.yknotify >/dev/null 2>&1", "", 0)
  end

  def stub_launchagent_unloaded
    @fake_system.stub_command("launchctl print gui/#{Process.uid}/com.user.yknotify >/dev/null 2>&1", "", 1)
  end

  def install_current_files
    @fake_system.write_file(script_path, step.send(:script_content))
    @fake_system.write_file(launchagent_path, step.send(:plist_content))
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
