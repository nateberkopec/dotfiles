class Dotfiles::Step::ConfigureRaycastHotkeyStep < Dotfiles::Step
  DESCRIPTION = "Configures Raycast as the Cmd-Space launcher and disables Spotlight's conflicting shortcut.".freeze

  RAYCAST_DOMAIN = "com.raycast.macos".freeze
  RAYCAST_HOTKEY = "Command-49".freeze
  SPOTLIGHT_HOTKEY_ID = "64".freeze

  macos_only

  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep]
  end

  def should_run?
    !raycast_configured? || !spotlight_disabled?
  end

  def run
    write_raycast_hotkey
    disable_spotlight_hotkey
    restart_preferences
  end

  def complete?
    super
    return true if raycast_configured? && spotlight_disabled?

    add_notice(title: "Raycast hotkey setup needs manual verification", message: manual_setup_message)
    true
  end

  private

  def write_raycast_hotkey
    execute(command("defaults", "write", RAYCAST_DOMAIN, "raycastGlobalHotkey", "-string", RAYCAST_HOTKEY))
    execute(command("defaults", "write", RAYCAST_DOMAIN, "onboarding_setupHotkey", "-bool", "true"))
  end

  def disable_spotlight_hotkey
    @system.mkdir_p(File.dirname(symbolic_hotkeys_plist))
    execute(plistbuddy_command("Add :AppleSymbolicHotKeys dict"))
    execute(plistbuddy_command("Add :AppleSymbolicHotKeys:#{SPOTLIGHT_HOTKEY_ID} dict"))
    _, status = execute(plistbuddy_command("Set :AppleSymbolicHotKeys:#{SPOTLIGHT_HOTKEY_ID}:enabled false"))
    execute(plistbuddy_command("Add :AppleSymbolicHotKeys:#{SPOTLIGHT_HOTKEY_ID}:enabled bool false")) unless status == 0
  end

  def restart_preferences
    execute(command("killall", "cfprefsd"))
    execute(command("killall", "SystemUIServer"))
  end

  def raycast_configured?
    defaults_value?("raycastGlobalHotkey", RAYCAST_HOTKEY) && defaults_bool?("onboarding_setupHotkey")
  end

  def spotlight_disabled?
    output, status = execute(plistbuddy_command("Print :AppleSymbolicHotKeys:#{SPOTLIGHT_HOTKEY_ID}:enabled"))
    status == 0 && false_value?(output)
  end

  def defaults_value?(key, expected)
    output, status = execute(command("defaults", "read", RAYCAST_DOMAIN, key))
    status == 0 && output == expected
  end

  def defaults_bool?(key)
    output, status = execute(command("defaults", "read", RAYCAST_DOMAIN, key))
    status == 0 && true_value?(output)
  end

  def plistbuddy_command(plist_command)
    command("/usr/libexec/PlistBuddy", "-c", plist_command, symbolic_hotkeys_plist)
  end

  def true_value?(value)
    %w[1 true yes].include?(value.to_s.downcase)
  end

  def false_value?(value)
    %w[0 false no].include?(value.to_s.downcase)
  end

  def symbolic_hotkeys_plist
    File.join(@home, "Library", "Preferences", "com.apple.symbolichotkeys.plist")
  end

  def manual_setup_message
    <<~TEXT
      1. System Settings → Keyboard → Keyboard Shortcuts → Spotlight
      2. Disable “Show Spotlight search”
      3. Raycast → Settings → General
      4. Set Raycast Hotkey to ⌘ Space
      5. Restart Raycast if the hotkey does not apply immediately
    TEXT
  end
end
