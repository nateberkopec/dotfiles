class Dotfiles::Step::ConfigureIceStep < Dotfiles::Step
  def self.display_name
    "Ice Menu Bar Configuration"
  end

  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep]
  end

  def should_run?
    ice_installed? && !complete?
  end

  def run
    debug "Configuring Ice menu bar manager..."
    configure_preferences
    configure_launch_at_login
    restart_ice
  end

  def complete?
    ice_preferences = app_path("ice_preferences")
    return false unless ice_preferences && @system.file_exist?(ice_preferences)
    launch_at_login_configured?
  end

  def update
    copy_if_exists(app_path("ice_preferences"), dotfiles_source("ice_config"))
  end

  private

  def ice_installed?
    @system.file_exist?("/Applications/Ice.app")
  end

  def configure_preferences
    ice_preferences = app_path("ice_preferences")
    ice_config = dotfiles_source("ice_config")
    @system.cp(ice_config, ice_preferences)
  end

  def configure_launch_at_login
    execute("osascript -e 'tell application \"System Events\" to make login item at end with properties {path:\"/Applications/Ice.app\", hidden:false}'")
  end

  def launch_at_login_configured?
    output, status = execute("osascript -e 'tell application \"System Events\" to get the name of every login item'", quiet: true)
    return false unless status == 0
    output.include?("Ice")
  end

  def restart_ice
    execute("killall Ice 2>/dev/null; open -a Ice")
  end
end
