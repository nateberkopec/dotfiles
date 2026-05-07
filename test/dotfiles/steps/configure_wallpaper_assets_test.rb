require "test_helper"
require_relative "../../support/wallpaper_step_helper"

class ConfigureWallpaperAssetsTest < StepTestCase
  include WallpaperStepHelper

  step_class Dotfiles::Step::ConfigureWallpaperStep

  def test_run_installs_manual_wallpaper_command
    step.run

    assert_command_run(:mkdir_p, File.dirname(script_path))
    assert_command_run(:chmod, 0o755, script_path)
    assert @fake_system.file_exist?(script_path)
  end

  def test_script_loads_private_fish_credentials_and_runs_woodblock_query
    step.run

    content = @fake_system.read_file(script_path)
    assert_includes content, 'source "$private_fish"'
    assert_includes content, "UNSPLASH_CLIENT_ID UNSPLASH_CLIENT_SECRET"
    assert_includes content, 'command splash --plain --query "woodblock print" --orientation "landscape" --no-cache $argv'
  end

  def test_run_installs_daily_launchagent
    step.run

    content = @fake_system.read_file(launchagent_path)
    assert_includes content, "<string>#{fish_path}</string>"
    assert_includes content, "<string>#{script_path}</string>"
    assert_includes content, "<key>StartCalendarInterval</key>"
    assert_includes content, "<integer>5</integer>"
    assert_includes content, "<integer>0</integer>"
  end

  def test_run_loads_launchagent
    step.run

    assert_executed("launchctl bootout gui/#{Process.uid} #{launchagent_path} 2>/dev/null || true")
    assert_executed("launchctl enable gui/#{Process.uid}/com.user.woodblock-wallpaper")
    assert_executed("launchctl bootstrap gui/#{Process.uid} #{launchagent_path}")
    assert_executed("launchctl kickstart -k gui/#{Process.uid}/com.user.woodblock-wallpaper")
  end

  def test_custom_wallpaper_settings_are_used
    settings = {"query" => "ukiyo-e", "orientation" => "landscape", "hour" => 6, "minute" => 30}
    write_config(:wallpaper, {"wallpaper_settings" => settings})

    step.run

    assert_includes @fake_system.read_file(script_path), '--query "ukiyo-e"'
    plist = @fake_system.read_file(launchagent_path)
    assert_includes plist, "<integer>6</integer>"
    assert_includes plist, "<integer>30</integer>"
  end
end
