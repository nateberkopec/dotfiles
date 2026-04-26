class Dotfiles::Step::InstallYknotifyStep < Dotfiles::Step
  DESCRIPTION = "Installs yknotify notification integration and its LaunchAgent on macOS.".freeze

  include Dotfiles::Step::LaunchCtl

  macos_only

  def self.depends_on
    [Dotfiles::Step::InstallMiseToolsStep, Dotfiles::Step::InstallBrewPackagesStep]
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

  def script_current?
    file_installed_with_content?(script_path, script_content)
  end

  def launchagent_current?
    file_installed_with_content?(launchagent_path, plist_content)
  end

  def launchagent_loaded?
    command_succeeds?("launchctl print gui/#{Process.uid}/#{launchagent_label} >/dev/null 2>&1")
  end

  def install_yknotify_script
    install_script(script_path, script_content)
    install_icon
  end

  def install_icon
    debug "Installing YubiKey icon (BSD 2-Clause, Yubico AB)..."
    execute("curl -sL 'https://raw.githubusercontent.com/Yubico/yubikey-manager-qt/main/ykman-gui/images/windowicon.png' -o '#{icon_path}'")
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

  def launchagent_label
    File.basename(launchagent_path, ".plist")
  end

  def file_installed_with_content?(path, content)
    @system.file_exist?(path) && @system.read_file(path) == content
  end

  def mise_bin_path
    [
      File.join(@home, ".homebrew", "bin", "mise"),
      "/opt/homebrew/bin/mise",
      "/usr/local/bin/mise",
      "/opt/homebrew/opt/mise/bin/mise",
      "/usr/local/opt/mise/bin/mise"
    ].find { |path| @system.file_exist?(path) } || "mise"
  end

  def terminal_notifier_path
    [
      File.join(@home, ".homebrew", "bin", "terminal-notifier"),
      "/opt/homebrew/bin/terminal-notifier",
      "/usr/local/bin/terminal-notifier"
    ].find { |path| @system.file_exist?(path) } || "terminal-notifier"
  end

  def script_content
    <<~BASH
      #!/bin/bash

      # List of sounds: https://apple.stackexchange.com/a/479714
      export PATH="#{@home}/.local/bin:#{@home}/.homebrew/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

      MISE_BIN="#{mise_bin_path}"
      YKNTFY_BIN="$($MISE_BIN which yknotify 2>/dev/null)"
      if [[ -z "$YKNTFY_BIN" ]]; then
          YKNTFY_BIN="$(command -v yknotify 2>/dev/null)"
      fi
      if [[ -z "$YKNTFY_BIN" || ! -x "$YKNTFY_BIN" ]]; then
          echo "yknotify binary not found" >&2
          exit 1
      fi

      TERM_NTFY_BIN="#{terminal_notifier_path}"
      ICON_PATH="#{icon_path}"

      # Tighten log predicate to reduce background CPU usage.
      YKNTFY_PREDICATE='(processImagePath == "/kernel" AND senderImagePath ENDSWITH "IOHIDFamily" AND (eventMessage CONTAINS "IOHIDLibUserClient" OR eventMessage CONTAINS "AppleUserUSBHostHIDDevice" OR eventMessage ENDSWITH "startQueue" OR eventMessage ENDSWITH "stopQueue")) OR (processImagePath ENDSWITH "usbsmartcardreaderd" AND subsystem CONTAINS "CryptoTokenKit")'
      YKNTFY_ARGS=(-predicate "$YKNTFY_PREDICATE")

      LAST_NTFY=0
      # Read one yknotify event per process so stale FIDO2 state does not loop forever.
      while true; do
          TEMP_FIFO="$(mktemp "${TMPDIR:-/tmp}/yknotify.XXXXXX")"
          rm -f "$TEMP_FIFO"
          mkfifo "$TEMP_FIFO"

          "$YKNTFY_BIN" "${YKNTFY_ARGS[@]}" > "$TEMP_FIFO" &
          YKNTFY_PID=$!

          line=""
          if IFS= read -r line < "$TEMP_FIFO"; then
              kill "$YKNTFY_PID" 2>/dev/null || true
              wait "$YKNTFY_PID" 2>/dev/null || true
          else
              wait "$YKNTFY_PID" 2>/dev/null || true
          fi

          rm -f "$TEMP_FIFO"

          if [[ -z "$line" ]]; then
              sleep 1
              continue
          fi

          NOW="$(date +%s)"
          if [[ "$NOW" -le "$((LAST_NTFY + 2))" ]]; then
              continue
          fi
          LAST_NTFY="$NOW"

          message="$(echo "$line" | jq -r '.type')"
          if [[ -x "$TERM_NTFY_BIN" ]]; then
              "$TERM_NTFY_BIN" -title "YubiKey" -message "Touch to confirm $message" -sound Submarine -ignoreDnD -contentImage "$ICON_PATH"
          else
              osascript -e "display notification \\"$message\\" with title \\"yknotify\\""
          fi
      done
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
