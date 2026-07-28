class Dotfiles::Step::InstallYknotifyStep < Dotfiles::Step
  DESCRIPTION = "Installs yknotify notification integration and its LaunchAgent on macOS.".freeze

  macos_only

  def self.depends_on
    [Dotfiles::Step::InstallMiseToolsStep, Dotfiles::Step::InstallSystemPackagesStep]
  end

  def should_run?
    return false if ENV["CI"]
    !yknotify_installed? || !script_current?
  end

  def run
    install_yknotify_script unless script_current?
  end

  def complete?
    return true if ENV["CI"]
    super
    add_error("yknotify binary not found on PATH") unless yknotify_installed?
    add_error("terminal-notifier not found on PATH") unless terminal_notifier_installed?
    add_error("yknotify script not installed at #{script_path}") unless script_current?
    @errors.empty?
  end

  private

  def yknotify_installed?
    command_exists?("yknotify")
  end

  def terminal_notifier_installed?
    command_exists?("terminal-notifier")
  end

  def install_yknotify_script
    install_script(script_path, script_content)
    install_icon
  end

  def install_icon
    debug "Installing tracked YubiKey icon (BSD 2-Clause, Yubico AB)..."
    @system.cp(source_icon_path, icon_path)
  end

  def icon_path
    File.join(script_dir, "yubikey-icon.png")
  end

  def script_dir
    File.join(@home, ".local/share/yknotify")
  end

  def script_path
    File.join(script_dir, "yknotify.sh")
  end

  def source_script_path
    File.join(@dotfiles_dir, "files/yknotify/yknotify.sh")
  end

  def source_icon_path
    File.join(@dotfiles_dir, "files/yknotify/yubikey-icon.png")
  end

  def script_content
    @system.read_file(source_script_path)
  end

end
