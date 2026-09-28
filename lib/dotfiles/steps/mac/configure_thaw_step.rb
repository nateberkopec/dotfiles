class Dotfiles::Step::ConfigureThawStep < Dotfiles::Step
  DESCRIPTION = "Configures portable Thaw preferences and login startup.".freeze

  macos_only

  def self.depends_on
    [Dotfiles::Step::InstallThawAppStep]
  end

  def should_run?
    thaw_installed? && super
  end

  def run
    configure_preferences unless preferences_complete?
    configure_login_item unless login_item_complete?
  rescue ArgumentError, RuntimeError => e
    add_error(e.message)
  end

  def complete?
    return true unless thaw_installed?

    super
    add_error("Managed Thaw preferences differ") unless preferences_complete?
    add_error("Thaw login item is missing or stale") unless login_item_complete?
    @errors.empty?
  rescue ArgumentError => e
    add_error(e.message)
    false
  end

  private

  def configure_preferences
    was_running = thaw_running?
    stopped = quit_thaw if was_running
    preferences.apply
  ensure
    reopen_thaw if stopped
  end

  def quit_thaw
    _output, status = execute(command("osascript", "-e", 'tell application id "com.stonerl.Thaw" to quit'))
    raise "Failed to quit Thaw before changing preferences" unless status == 0

    _output, status = execute(shell_script("for _ in {1..50}; do pgrep -x Thaw >/dev/null || exit 0; sleep 0.1; done; exit 1"))
    raise "Thaw did not quit before changing preferences" unless status == 0
    true
  end

  def reopen_thaw
    _output, status = execute(command("open", "-b", "com.stonerl.Thaw"))
    raise "Failed to reopen Thaw after changing preferences" unless status == 0
  end

  def preferences_complete?
    preferences.complete?
  end

  def preferences
    @preferences ||= Dotfiles::ThawPreferences.new(
      repository_path: File.join(@dotfiles_dir, "config", "thaw.yml"),
      local_path: File.join(@home, ".config", "dotfiles", "thaw.local.yml"),
      system: @system
    )
  end

  def thaw_running?
    _output, status = execute(command("pgrep", "-x", "Thaw"), quiet: true)
    status == 0
  end

  def login_item_complete?
    output, status = execute(login_item_path_command, quiet: true)
    status == 0 && output == thaw_application_path
  end

  def configure_login_item
    _output, status = execute(command(
      "osascript",
      "-e", 'tell application "System Events"',
      "-e", 'if exists login item "Thaw" then delete login item "Thaw"',
      "-e", "make login item at end with properties {name:\"Thaw\", path:\"#{thaw_application_path}\", hidden:false}",
      "-e", "end tell"
    ))
    raise "Failed to configure the Thaw login item" unless status == 0
  end

  def login_item_path_command
    command(
      "osascript",
      "-e", 'tell application "System Events"',
      "-e", 'if exists login item "Thaw" then get path of login item "Thaw"',
      "-e", "end tell"
    )
  end

  def thaw_installed?
    !thaw_application_path.nil?
  end

  def thaw_application_path
    [File.join(@home, "Applications", "Thaw.app"), "/Applications/Thaw.app"].find do |path|
      @system.dir_exist?(path)
    end
  end
end
