require "test_helper"
require_relative "../../support/wallpaper_step_helper"

class ConfigureWallpaperStepTest < StepTestCase
  include WallpaperStepHelper

  step_class Dotfiles::Step::ConfigureWallpaperStep

  def test_depends_on_mise_tools
    assert_equal [Dotfiles::Step::InstallMiseToolsStep], self.class.step_class.depends_on
  end

  def test_skips_in_ci
    with_ci do
      refute step.should_run?
      assert step.complete?
    end
  end

  def test_should_run_when_splash_is_missing
    stub_splash_missing
    install_current_files
    stub_launchagent_loaded

    assert_should_run
  end

  def test_should_not_run_when_fully_installed
    stub_splash_on_path
    install_current_files
    stub_launchagent_loaded

    refute_should_run
  end

  def test_complete_when_all_installed
    stub_splash_on_path
    install_current_files
    stub_launchagent_loaded

    assert_complete
  end

  def test_incomplete_when_launchagent_unloaded
    stub_splash_on_path
    install_current_files
    stub_launchagent_unloaded

    assert_incomplete
  end

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
end
