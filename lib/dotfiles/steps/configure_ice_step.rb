class Dotfiles::Step::ConfigureIceStep < Dotfiles::Step
  def self.display_name
    "Ice Menu Bar Configuration"
  end

  def self.depends_on
    [Dotfiles::Step::SyncHomeDirectoryStep]
  end

  def should_run?
    return false if ci_or_noninteractive?
    ice_installed? && !complete?
  end

  def run
    debug "Configuring Ice menu bar manager..."
    configure_launch_at_login
    restart_ice
  end

  def complete?
    super
    return true if ci_or_noninteractive?

    ice_preferences = File.join(@home, "Library", "Preferences", "com.jordanbaird.Ice.plist")

    unless @system.file_exist?(ice_preferences)
      add_error("Ice preferences file does not exist at #{ice_preferences}")
      return false
    end

    unless launch_at_login_configured?
      add_error("Ice is not configured to launch at login")
      return false
    end

    true
  end

  private

  def ice_installed?
    @system.file_exist?("/Applications/Ice.app")
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
