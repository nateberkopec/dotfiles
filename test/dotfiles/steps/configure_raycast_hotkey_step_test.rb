require "test_helper"

class ConfigureRaycastHotkeyStepTest < StepTestCase
  step_class Dotfiles::Step::ConfigureRaycastHotkeyStep

  def test_depends_on_homebrew_package_install
    assert_equal [Dotfiles::Step::InstallBrewPackagesStep], self.class.step_class.depends_on
  end

  def test_should_run_when_raycast_hotkey_or_spotlight_setting_missing
    stub_raycast_hotkey("Command-49")
    stub_raycast_onboarding(true)
    stub_spotlight_enabled(true)

    assert_should_run
  end

  def test_run_writes_raycast_defaults_and_disables_spotlight_hotkey
    step.run

    assert_executed("defaults write com.raycast.macos raycastGlobalHotkey -string Command-49")
    assert_executed("defaults write com.raycast.macos onboarding_setupHotkey -bool true")
    assert_command_run(:mkdir_p, File.join(@home, "Library", "Preferences"))
    assert_executed(plistbuddy_command("Set :AppleSymbolicHotKeys:64:enabled false"))
    assert_executed("killall cfprefsd")
    assert_executed("killall SystemUIServer")
  end

  def test_complete_when_raycast_hotkey_is_set_and_spotlight_is_disabled
    stub_raycast_hotkey("Command-49")
    stub_raycast_onboarding(true)
    stub_spotlight_enabled(false)

    assert_complete
    assert_empty step.notices
  end

  def test_adds_manual_setup_notice_when_automation_cannot_verify
    stub_raycast_hotkey("Option-49")
    stub_raycast_onboarding(false)
    stub_spotlight_enabled(true)

    assert_complete
    notice = step.notices.first
    assert_includes notice[:title], "Raycast hotkey"
    assert_includes notice[:message], "System Settings → Keyboard"
    assert_includes notice[:message], "Set Raycast Hotkey to ⌘ Space"
  end

  private

  def stub_raycast_hotkey(value)
    @fake_system.stub_command("defaults read com.raycast.macos raycastGlobalHotkey", value)
  end

  def stub_raycast_onboarding(value)
    @fake_system.stub_command("defaults read com.raycast.macos onboarding_setupHotkey", value ? "1" : "0")
  end

  def stub_spotlight_enabled(value)
    @fake_system.stub_command(plistbuddy_command("Print :AppleSymbolicHotKeys:64:enabled"), value ? "true" : "false")
  end

  def plistbuddy_command(plist_command)
    ["/usr/libexec/PlistBuddy", "-c", plist_command, plist_path]
  end

  def plist_path
    File.join(@home, "Library", "Preferences", "com.apple.symbolichotkeys.plist")
  end
end
