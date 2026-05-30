require "test_helper"

class ConfigureRaycastHotkeyStepTest < StepTestCase
  step_class Dotfiles::Step::ConfigureRaycastHotkeyStep

  def test_default_return_value_is_incomplete
    assert_incomplete
  end

  def test_depends_on_homebrew_package_install
    assert_includes Dotfiles::Step::ConfigureRaycastHotkeyStep.depends_on,
      Dotfiles::Step::InstallBrewPackagesStep
  end

  def test_run_writes_raycast_defaults
    step.run

    assert_executed("defaults write com.raycast.macos raycastGlobalHotkey -string Command-49")
    assert_executed("defaults write com.raycast.macos onboarding_setupHotkey -bool true")
  end

  def test_run_disables_spotlight_hotkey_64
    step.run

    command = executed_bash_scripts.find { |script, _arg| script.include?("AppleSymbolicHotKeys:64:enabled false") }
    assert command, "Expected run to disable Spotlight symbolic hotkey 64"
    assert_equal spotlight_hotkeys_plist, command.last
  end

  def test_run_restarts_preference_agents
    step.run

    assert executed_bash_scripts.any? { |script, _arg| script.include?("killall cfprefsd") }
    assert executed_bash_scripts.any? { |script, _arg| script.include?("killall SystemUIServer") }
  end

  def test_complete_when_raycast_hotkey_is_command_space_and_spotlight_64_is_disabled
    stub_raycast_configured
    stub_spotlight_disabled

    assert_complete
  end

  def test_incomplete_when_spotlight_64_is_enabled
    stub_raycast_configured
    @fake_system.stub_command(
      "/usr/libexec/PlistBuddy -c 'Print :AppleSymbolicHotKeys:64:enabled' #{spotlight_hotkeys_plist}",
      "true",
      0
    )

    assert_incomplete
  end

  def test_run_adds_manual_setup_notice_when_automation_cannot_be_verified
    step.run

    notice = step.notices.first
    assert notice, "Expected a manual setup notice"
    assert_includes notice[:message], "System Settings → Keyboard"
    assert_includes notice[:message], "Raycast → Settings → General"
  end

  private

  def stub_raycast_configured
    @fake_system.stub_command("defaults read com.raycast.macos raycastGlobalHotkey", "Command-49", 0)
    @fake_system.stub_command("defaults read com.raycast.macos onboarding_setupHotkey", "1", 0)
  end

  def stub_spotlight_disabled
    @fake_system.stub_command(
      "/usr/libexec/PlistBuddy -c 'Print :AppleSymbolicHotKeys:64:enabled' #{spotlight_hotkeys_plist}",
      "false",
      0
    )
  end

  def executed_bash_scripts
    @fake_system.operations.filter_map do |operation, command, _options|
      next unless operation == :execute
      next unless command.is_a?(Array) && command[0, 2] == ["bash", "-c"]

      [command[2], command[4]]
    end
  end

  def spotlight_hotkeys_plist
    File.join(@home, "Library", "Preferences", "com.apple.symbolichotkeys.plist")
  end
end
