class Dotfiles::Step::ConfigureWallpaperStep < Dotfiles::Step
  DESCRIPTION = "Installs the Unsplash woodblock wallpaper command and daily LaunchAgent.".freeze

  include Dotfiles::Step::LaunchCtl

  macos_only

  def run
    install_script(script_path, script_content) unless script_current?
    install_plist(launchagent_path, plist_content) unless launchagent_current?
    load_launchagent(launchagent_path)
  end

  def complete?
    return true if ENV["CI"]
    super
    wallpaper_errors.each { |message| add_error(message) }
    @errors.empty?
  end

  private

  def wallpaper_errors
    [
      ("splash CLI not found on PATH" unless splash_installed?),
      ("Wallpaper command not installed at #{script_path}" unless script_current?),
      ("LaunchAgent not installed at #{launchagent_path}" unless launchagent_current?),
      ("LaunchAgent not loaded: #{launchagent_label}" unless launchagent_loaded?)
    ].compact
  end

  def splash_installed?
    command_exists?("splash")
  end

  def script_content
    @system.read_file(source_script_path)
  end

  def plist_content
    @system.read_file(plist_template_path)
      .gsub("__FISH_PATH__", find_fish_path)
      .gsub("__SCRIPT_PATH__", script_path)
      .gsub("__HOME__", @home)
  end

  def source_script_path
    File.join(@dotfiles_dir, "files/home/.local/bin/set-woodblock-wallpaper")
  end

  def plist_template_path
    File.join(@dotfiles_dir, "files/templates/com.user.woodblock-wallpaper.plist")
  end

  def script_path
    File.join(@home, ".local/bin/set-woodblock-wallpaper")
  end

  def launchagent_path
    File.join(@home, "Library/LaunchAgents/com.user.woodblock-wallpaper.plist")
  end
end
