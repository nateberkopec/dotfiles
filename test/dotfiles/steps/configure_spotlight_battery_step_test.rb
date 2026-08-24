require "test_helper"

class ConfigureSpotlightBatteryStepTest < StepTestCase
  step_class Dotfiles::Step::ConfigureSpotlightBatteryStep

  def test_should_run_when_battery_mode_enabled_and_missing_launchdaemon
    write_spotlight_config
    stub_fish_path
    stub_macos

    assert_should_run
  end

  def test_run_installs_script_and_launchdaemon
    write_spotlight_config
    stub_fish_path

    step.run

    assert_command_run(:mkdir_p, script_dir)
    assert_command_run(:chmod, 0o755, script_path)
    assert @fake_system.file_exist?(script_path)
    assert @fake_system.file_exist?(launchdaemon_source_path)

    assert_executed("sudo install -m 644 #{launchdaemon_source_path} #{launchdaemon_path}", quiet: false)
    assert_executed("sudo launchctl bootout system #{launchdaemon_path} 2>/dev/null || true", quiet: false)
    assert_executed("sudo launchctl bootstrap system #{launchdaemon_path}", quiet: false)

    plist = @fake_system.read_file(launchdaemon_source_path)
    assert_includes plist, fish_path
    assert_includes plist, script_path
    assert_includes plist, "<string>/</string>"
    assert_includes plist, "<string>/System/Volumes/Data</string>"
  end

  def test_generated_script_keeps_desired_state_in_scope
    write_spotlight_config
    stub_fish_path

    script = step.send(:script_content)

    assert_includes script, "set -l desired\n"
    assert_includes script, "set desired off"
    assert_includes script, "set desired on"
    refute_includes script, "set -l desired off"
    refute_includes script, "set -l desired on"
  end

  def test_should_run_when_generated_files_are_stale
    write_spotlight_config
    stub_fish_path
    @fake_system.write_file(script_path, "stale")
    @fake_system.write_file(launchdaemon_path, "stale")

    assert_should_run
  end

  def test_run_replaces_stale_generated_files
    write_spotlight_config
    stub_fish_path
    @fake_system.write_file(script_path, "stale")
    @fake_system.write_file(launchdaemon_path, "stale")

    step.run

    assert_equal step.send(:script_content), @fake_system.read_file(script_path)
    assert_equal step.send(:plist_content), @fake_system.read_file(launchdaemon_source_path)
    assert_executed("sudo install -m 644 #{launchdaemon_source_path} #{launchdaemon_path}", quiet: false)
  end

  def test_complete_when_battery_mode_installed
    write_spotlight_config
    stub_fish_path
    write_current_generated_files

    assert_complete
  end

  def test_complete_in_ci_when_launchdaemon_missing
    write_spotlight_config
    stub_fish_path
    @fake_system.write_file(script_path, "")

    with_ci { assert_complete }
  end

  def test_complete_when_battery_mode_disabled
    write_spotlight_config("battery_disable" => false)
    assert_complete
  end

  private

  def write_spotlight_config(overrides = {})
    settings = {
      "battery_disable" => true,
      "battery_volumes" => ["/", "/System/Volumes/Data"],
      "check_interval_seconds" => 60
    }.merge(overrides)
    write_config("spotlight", "spotlight_settings" => settings)
  end

  def stub_fish_path
    @fake_system.stub_command("command -v fish 2>/dev/null", fish_path, 0)
  end

  def stub_macos
    @fake_system.define_singleton_method(:macos?) { true }
  end

  def write_current_generated_files
    @fake_system.write_file(script_path, step.send(:script_content))
    @fake_system.write_file(launchdaemon_path, step.send(:plist_content))
  end

  def fish_path
    "/opt/homebrew/bin/fish"
  end

  def script_dir
    File.join(@home, ".local", "share", "spotlight")
  end

  def script_path
    File.join(script_dir, "spotlight-battery.fish")
  end

  def launchdaemon_source_path
    File.join(script_dir, "com.user.spotlight-battery.plist")
  end

  def launchdaemon_path
    "/Library/LaunchDaemons/com.user.spotlight-battery.plist"
  end
end
