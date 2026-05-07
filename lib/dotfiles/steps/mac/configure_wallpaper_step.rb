class Dotfiles::Step::ConfigureWallpaperStep < Dotfiles::Step
  DESCRIPTION = "Installs the Unsplash woodblock wallpaper command and daily LaunchAgent.".freeze

  include Dotfiles::Step::LaunchCtl
  include Dotfiles::Step::ConfigureWallpaperAssets

  macos_only

  def self.depends_on
    [Dotfiles::Step::InstallFishShellStep, Dotfiles::Step::InstallBrewPackagesStep]
  end

  def should_run?
    return false if ENV["CI"]
    wallpaper_checks.any? { |check| !send(check) }
  end

  def run
    install_wallpaper_command
    install_wallpaper_schedule
    load_launchagent(launchagent_path)
  end

  def complete?
    return true if ENV["CI"]
    super
    wallpaper_errors.each { |message| add_error(message) }
    @errors.empty?
  end

  private

  def wallpaper_checks
    [:splash_installed?, :script_current?, :launchagent_current?, :launchagent_loaded?]
  end

  def wallpaper_errors
    [
      ("splash CLI not found on PATH" unless splash_installed?),
      ("Wallpaper command not installed at #{script_path}" unless script_current?),
      ("LaunchAgent not installed at #{launchagent_path}" unless launchagent_current?),
      ("LaunchAgent not loaded: #{launchagent_label}" unless launchagent_loaded?)
    ].compact
  end

  def install_wallpaper_command
    install_script(script_path, script_content) unless script_current?
  end

  def install_wallpaper_schedule
    install_plist(launchagent_path, plist_content) unless launchagent_current?
  end

  def splash_installed?
    command_exists?("splash")
  end

  def script_current?
    file_installed_with_content?(script_path, script_content)
  end

  def launchagent_current?
    file_installed_with_content?(launchagent_path, plist_content)
  end

  def launchagent_loaded?
    command_succeeds?(command("launchctl", "print", "gui/#{Process.uid}/#{launchagent_label}"))
  end

  def file_installed_with_content?(path, content)
    @system.file_exist?(path) && @system.read_file(path) == content
  end

  def script_path
    File.join(@home, ".local/bin/set-woodblock-wallpaper")
  end

  def launchagent_path
    File.join(@home, "Library/LaunchAgents/com.user.woodblock-wallpaper.plist")
  end

  def launchagent_label
    File.basename(launchagent_path, ".plist")
  end
end
