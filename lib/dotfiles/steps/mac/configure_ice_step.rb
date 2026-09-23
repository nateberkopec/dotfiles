class Dotfiles::Step::ConfigureIceStep < Dotfiles::Step
  DESCRIPTION = "Configures portable Ice preferences and login startup.".freeze

  macos_only

  def self.depends_on
    [Dotfiles::Step::InstallBrewCasksStep]
  end

  def should_run?
    ice_installed? && super
  end

  def run
    configure_preferences unless preferences_complete?
    configure_login_item unless login_item_complete?
  rescue ArgumentError, RuntimeError => e
    add_error(e.message)
  end

  def complete?
    return true unless ice_installed?

    super
    add_error("Managed Ice preferences differ") unless preferences_complete?
    add_error("Ice login item is missing or stale") unless login_item_complete?
    @errors.empty?
  rescue ArgumentError => e
    add_error(e.message)
    false
  end

  private

  def configure_preferences
    was_running = ice_running?
    stopped = quit_ice if was_running
    preferences.apply
  ensure
    reopen_ice if stopped
  end

  def quit_ice
    _output, status = execute(command("osascript", "-e", 'tell application id "com.jordanbaird.Ice" to quit'))
    raise "Failed to quit Ice before changing preferences" unless status == 0

    _output, status = execute(shell_script("for _ in {1..50}; do pgrep -x Ice >/dev/null || exit 0; sleep 0.1; done; exit 1"))
    raise "Ice did not quit before changing preferences" unless status == 0
    true
  end

  def reopen_ice
    _output, status = execute(command("open", "-b", "com.jordanbaird.Ice"))
    raise "Failed to reopen Ice after changing preferences" unless status == 0
  end

  def preferences_complete?
    preferences.complete?
  end

  def preferences
    @preferences ||= Dotfiles::IcePreferences.new(
      repository_path: File.join(@dotfiles_dir, "config", "ice.yml"),
      local_path: File.join(@home, ".config", "dotfiles", "ice.local.yml"),
      system: @system
    )
  end

  def ice_running?
    _output, status = execute(command("pgrep", "-x", "Ice"), quiet: true)
    status == 0
  end

  def login_item_complete?
    output, status = execute(login_item_path_command, quiet: true)
    status == 0 && output == ice_application_path
  end

  def configure_login_item
    _output, status = execute(command(
      "osascript",
      "-e", 'tell application "System Events"',
      "-e", 'if exists login item "Ice" then delete login item "Ice"',
      "-e", "make login item at end with properties {name:\"Ice\", path:\"#{ice_application_path}\", hidden:false}",
      "-e", "end tell"
    ))
    raise "Failed to configure the Ice login item" unless status == 0
  end

  def login_item_path_command
    command(
      "osascript",
      "-e", 'tell application "System Events"',
      "-e", 'if exists login item "Ice" then get path of login item "Ice"',
      "-e", "end tell"
    )
  end

  def ice_installed?
    !ice_application_path.nil?
  end

  def ice_application_path
    [File.join(@home, "Applications", "Ice.app"), "/Applications/Ice.app"].find do |path|
      @system.dir_exist?(path)
    end
  end
end
