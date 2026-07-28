class Dotfiles::Step::InstallYknotifyStep < Dotfiles::Step
  DESCRIPTION = "Installs yknotify notification integration and its LaunchAgent on macOS.".freeze

  include Dotfiles::Step::LaunchCtl

  macos_only

  def self.depends_on
    [Dotfiles::Step::InstallMiseToolsStep, Dotfiles::Step::InstallSystemPackagesStep]
  end

  def should_run?
    return false if ENV["CI"]
    !yknotify_installed? || !script_current? || !launchagent_current? || !launchagent_loaded?
  end

  def run
    install_yknotify_script unless script_current?
    install_plist(launchagent_path, plist_content) unless launchagent_current?
    load_launchagent(launchagent_path)
  end

  def complete?
    return true if ENV["CI"]
    super
    add_error("yknotify binary not found on PATH") unless yknotify_installed?
    add_error("terminal-notifier not found on PATH") unless terminal_notifier_installed?
    add_error("yknotify script not installed at #{script_path}") unless script_current?
    add_error("LaunchAgent not installed at #{launchagent_path}") unless launchagent_current?
    add_error("LaunchAgent not loaded: #{launchagent_label}") unless launchagent_loaded?
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

  def launchagent_path
    File.join(@home, "Library/LaunchAgents/com.user.yknotify.plist")
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

  def plist_content
    <<~PLIST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>Label</key>
          <string>com.user.yknotify</string>
          <key>ProgramArguments</key>
          <array>
              <string>/bin/bash</string>
              <string>#{script_path}</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
          <key>KeepAlive</key>
          <true/>
          <key>StandardOutPath</key>
          <string>/tmp/yknotify.out</string>
          <key>StandardErrorPath</key>
          <string>/tmp/yknotify.err</string>
      </dict>
      </plist>
    PLIST
  end
end
