module WallpaperStepHelper
  def setup
    super
    @fake_system.stub_macos
    stub_fish_path
  end

  private

  def stub_fish_path
    @fake_system.stub_command("command -v fish 2>/dev/null", "#{fish_path}\n", 0)
  end

  def stub_splash_on_path
    @fake_system.stub_command("command -v splash >/dev/null 2>&1", "", 0)
  end

  def stub_splash_missing
    @fake_system.stub_command("command -v splash >/dev/null 2>&1", "", 1)
  end

  def stub_launchagent_loaded
    @fake_system.stub_command("launchctl print gui/#{Process.uid}/com.user.woodblock-wallpaper >/dev/null 2>&1", "", 0)
  end

  def stub_launchagent_unloaded
    @fake_system.stub_command("launchctl print gui/#{Process.uid}/com.user.woodblock-wallpaper >/dev/null 2>&1", "", 1)
  end

  def install_current_files
    @fake_system.write_file(script_path, step.send(:script_content))
    @fake_system.write_file(launchagent_path, step.send(:plist_content))
  end

  def fish_path
    "/opt/homebrew/bin/fish"
  end

  def script_path
    File.join(@home, ".local/bin/set-woodblock-wallpaper")
  end

  def launchagent_path
    File.join(@home, "Library/LaunchAgents/com.user.woodblock-wallpaper.plist")
  end
end
