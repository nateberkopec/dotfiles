class Dotfiles::Step::ConfigureRaycastHotkeyStep < Dotfiles::Step
  DESCRIPTION = "Disables the macOS Spotlight Command-Space hotkey for Raycast.".freeze

  macos_only

  def self.depends_on
    [Dotfiles::Step::InstallBrewCasksStep]
  end

  def run
    debug "Disabling the Spotlight Command-Space hotkey..."
    disable_spotlight_hotkey
    restart_preferences_agents
    add_manual_setup_notice unless complete?
  end

  def complete?
    super
    disabled = spotlight_hotkey_disabled?
    add_error("Spotlight Command-Space hotkey is still enabled") unless disabled
    disabled
  end

  private

  def disable_spotlight_hotkey
    execute(shell_script(disable_spotlight_script, spotlight_hotkeys_plist))
  end

  def restart_preferences_agents
    execute(shell_script("killall cfprefsd 2>/dev/null || true\nkillall SystemUIServer 2>/dev/null || true"))
  end

  def spotlight_hotkey_disabled?
    output, status = execute(
      command("/usr/libexec/PlistBuddy", "-c", "Print :AppleSymbolicHotKeys:64:enabled", spotlight_hotkeys_plist),
      quiet: true
    )
    status == 0 && ["false", "0"].include?(output.downcase)
  end

  def add_manual_setup_notice
    add_notice(title: "⌘ Space setup required", message: manual_setup_message)
  end

  def manual_setup_message
    [
      "The Spotlight Command-Space hotkey could not be disabled automatically.",
      "",
      "1. System Settings → Keyboard → Keyboard Shortcuts → Spotlight",
      "2. Disable “Show Spotlight search”",
      "3. Raycast → Settings → General",
      "4. Set Raycast Hotkey to ⌘ Space",
      "5. Restart Raycast if the hotkey does not apply immediately"
    ].join("\n")
  end

  def disable_spotlight_script
    <<~BASH
      plist="$1"
      /usr/libexec/PlistBuddy -c "Print :AppleSymbolicHotKeys" "$plist" >/dev/null 2>&1 || \
        /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys dict" "$plist" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c "Print :AppleSymbolicHotKeys:64" "$plist" >/dev/null 2>&1 || \
        /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:64 dict" "$plist" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c "Set :AppleSymbolicHotKeys:64:enabled false" "$plist" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:64:enabled bool false" "$plist"
    BASH
  end

  def spotlight_hotkeys_plist
    File.join(@home, "Library", "Preferences", "com.apple.symbolichotkeys.plist")
  end
end
