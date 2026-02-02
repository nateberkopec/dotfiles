class Dotfiles::Step::InstallYknotifyStep < Dotfiles::Step
  macos_only

  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep]
  end

  def should_run?
    !yknotify_installed? || !launchagent_installed?
  end

  def run
    install_go_package unless yknotify_installed?
    install_script unless script_installed?
    install_launchagent unless launchagent_installed?
    load_launchagent
  end

  def complete?
    super
    add_error("yknotify binary not found on PATH") unless yknotify_installed?
    add_error("terminal-notifier not found on PATH") unless terminal_notifier_installed?
    add_error("LaunchAgent not installed at #{launchagent_path}") unless launchagent_installed?
    @errors.empty?
  end

  private

  def yknotify_installed?
    command_exists?("yknotify") || mise_has_yknotify? || go_bin_has_yknotify?
  end

  def mise_has_yknotify?
    _, status = @system.execute(mise_exec_command("which yknotify 2>/dev/null"))
    status == 0
  end

  def go_bin_has_yknotify?
    @system.file_exist?(go_bin_yknotify)
  end

  def go_bin_dir
    File.join(@home, "go/bin")
  end

  def go_bin_yknotify
    File.join(go_bin_dir, "yknotify")
  end

  def terminal_notifier_installed?
    command_exists?("terminal-notifier")
  end

  def launchagent_installed?
    @system.file_exist?(launchagent_path)
  end

  def script_installed?
    @system.file_exist?(script_path)
  end

  def install_go_package
    debug "Ensuring Go is available via mise..."
    execute("mise use -g go@latest")

    debug "Installing yknotify from upstream..."
    execute("mkdir -p #{go_bin_dir}")
    output, status = execute("GOBIN=#{go_bin_dir} #{mise_exec_command("go install github.com/noperator/yknotify@999f01c")}")
    raise "go install failed (status #{status}): #{output}" unless status == 0
    execute("mise reshim")
  end

  def install_script
    debug "Installing yknotify.sh to #{script_path}..."
    @system.mkdir_p(script_dir)
    @system.write_file(script_path, script_content)
    @system.chmod(0o755, script_path)
    install_icon
  end

  def install_icon
    debug "Installing YubiKey icon (BSD 2-Clause, Yubico AB)..."
    execute("curl -sL 'https://raw.githubusercontent.com/Yubico/yubikey-manager-qt/main/ykman-gui/images/windowicon.png' -o '#{icon_path}'")
  end

  def icon_path
    File.join(script_dir, "yubikey-icon.png")
  end

  def install_launchagent
    debug "Installing LaunchAgent to #{launchagent_path}..."
    @system.mkdir_p(File.dirname(launchagent_path))
    @system.write_file(launchagent_path, plist_content)
  end

  def load_launchagent
    debug "Loading LaunchAgent..."
    execute("launchctl unload #{launchagent_path} 2>/dev/null || true")
    execute("launchctl load #{launchagent_path}")
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

  def yknotify_bin_path
    find_binary_path(mise_exec_command("which yknotify 2>/dev/null")) ||
      find_binary_path("which yknotify") ||
      go_bin_yknotify_path
  end

  def go_bin_yknotify_path
    go_bin_yknotify if @system.file_exist?(go_bin_yknotify)
  end

  def find_binary_path(command)
    output, status = @system.execute(command)
    output.strip if status == 0 && !output.strip.empty?
  end

  def mise_exec_command(command)
    parts = ["mise", "exec"]
    parts << "--no-prepare" if mise_exec_supports_no_prepare?
    parts << "go@latest"
    parts << "--"
    "#{parts.join(" ")} #{command}"
  end

  def mise_exec_supports_no_prepare?
    return @mise_exec_supports_no_prepare if instance_variable_defined?(:@mise_exec_supports_no_prepare)
    output, status = @system.execute("mise exec --help")
    @mise_exec_supports_no_prepare = status == 0 && output.include?("--no-prepare")
  end

  def terminal_notifier_path
    "/opt/homebrew/bin/terminal-notifier"
  end

  def script_content
    <<~BASH
      #!/bin/bash

      # List of sounds: https://apple.stackexchange.com/a/479714

      # Adjust as needed
      YKNTFY_BIN="#{yknotify_bin_path}"

      # brew install terminal-notifier
      TERM_NTFY_BIN="#{terminal_notifier_path}"

      # Tighten log predicate to reduce background CPU usage.
      YKNTFY_PREDICATE='(processImagePath == "/kernel" AND senderImagePath ENDSWITH "IOHIDFamily" AND (eventMessage CONTAINS "IOHIDLibUserClient" OR eventMessage CONTAINS "AppleUserUSBHostHIDDevice" OR eventMessage ENDSWITH "startQueue" OR eventMessage ENDSWITH "stopQueue")) OR (processImagePath ENDSWITH "usbsmartcardreaderd" AND subsystem CONTAINS "CryptoTokenKit")'
      YKNTFY_ARGS=(-predicate "$YKNTFY_PREDICATE")

      # Stream yknotify output and process each line
      LAST_NTFY=0
      while IFS= read -r line; do

          # 2-second delay between notifications
          NOW="$(date +%s)"
          if [[ "$NOW" -le "$((LAST_NTFY + 2))" ]]; then
              continue
          fi
          LAST_NTFY="$NOW"

          # Send notification using terminal-notifier
          message="$(echo "$line" | jq -r '.type')"
          if [[ -x "$TERM_NTFY_BIN" ]]; then
              "$TERM_NTFY_BIN" -title "YubiKey" -message "Touch to confirm $message" -sound Submarine -ignoreDnD -contentImage "#{icon_path}"
          else
              # Fallback to AppleScript if terminal-notifier is not installed
              osascript -e "display notification \\"$message\\" with title \\"yknotify\\""
          fi

      done < <("$YKNTFY_BIN" "${YKNTFY_ARGS[@]}")
    BASH
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
