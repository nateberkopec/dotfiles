require "test_helper"

class ConfigureSpotlightIndexingStepTest < StepTestCase
  step_class Dotfiles::Step::ConfigureSpotlightIndexingStep

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

  def test_run_disables_configured_volumes
    write_spotlight_config("battery_disable" => false, "disabled_volumes" => ["/Volumes/Archive"])
    stub_df_mount("/Volumes/Archive", "/Volumes/Archive")
    stub_mdutil_status("/Volumes/Archive", "Indexing enabled.")

    step.run

    assert_executed("sudo mdutil -i off /Volumes/Archive", quiet: false)
  end

  def test_run_expands_tilde_for_disabled_volumes
    write_spotlight_config("battery_disable" => false, "disabled_volumes" => ["~/Documents/Code.nosync"])
    stub_df_mount(expanded_home_code_dir, "/System/Volumes/Data")
    @fake_system.mkdir_p(expanded_home_code_dir)

    step.run

    assert @fake_system.file_exist?(File.join(expanded_home_code_dir, ".metadata_never_index"))
  end

  def test_complete_when_battery_mode_installed
    write_spotlight_config
    stub_fish_path
    @fake_system.write_file(script_path, "")
    @fake_system.write_file(launchdaemon_path, "")

    assert_complete
  end

  def test_complete_in_ci_when_launchdaemon_missing
    write_spotlight_config
    stub_fish_path
    @fake_system.write_file(script_path, "")

    with_ci { assert_complete }
  end

  def test_incomplete_when_indexing_enabled_on_disabled_volume
    write_spotlight_config("battery_disable" => false, "disabled_volumes" => ["/Volumes/Archive"])
    stub_df_mount("/Volumes/Archive", "/Volumes/Archive")
    stub_mdutil_status("/Volumes/Archive", "Indexing enabled.")

    assert_incomplete
  end

  def test_complete_when_indexing_disabled_on_disabled_volume
    write_spotlight_config("battery_disable" => false, "disabled_volumes" => ["/Volumes/Archive"])
    stub_df_mount("/Volumes/Archive", "/Volumes/Archive")
    stub_mdutil_status("/Volumes/Archive", "Indexing disabled.")

    assert_complete
  end

  def test_incomplete_when_metadata_never_index_missing
    write_spotlight_config("battery_disable" => false, "disabled_volumes" => ["~/Documents/Code.nosync"])
    stub_df_mount(expanded_home_code_dir, "/System/Volumes/Data")
    @fake_system.mkdir_p(expanded_home_code_dir)

    assert_incomplete
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

  def stub_mdutil_status(volume, status_line)
    @fake_system.stub_command("mdutil -s #{volume}", "#{volume}:\n\t#{status_line}", 0)
  end

  def stub_df_mount(path, mount_point)
    output = <<~OUT
      Filesystem 512-blocks Used Available Capacity iused ifree %iused Mounted on
      /dev/disk3s1s1 3896910480 1 1 1% 1 1 1% #{mount_point}
    OUT
    @fake_system.stub_command("df -P #{path}", output, 0)
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

  def expanded_home_code_dir
    File.join(@home, "Documents", "Code.nosync")
  end
end
