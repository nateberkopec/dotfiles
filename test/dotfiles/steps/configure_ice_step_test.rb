require "test_helper"

class ConfigureIceStepTest < StepTestCase
  step_class Dotfiles::Step::ConfigureIceStep

  def setup
    super
    source = Dotfiles::SystemAdapter.new.read_file(File.expand_path("../../../config/ice.yml", __dir__))
    @fake_system.stub_file_content(File.join(@dotfiles_dir, "config", "ice.yml"), source)
  end

  def test_default_return_value_is_incomplete
    assert_incomplete
  end

  def test_depends_on_homebrew_cask_install
    assert_includes Dotfiles::Step::ConfigureIceStep.depends_on, Dotfiles::Step::InstallBrewCasksStep
  end

  def test_run_quits_and_reopens_running_ice_when_preferences_drift
    @fake_system.stub_command(["defaults", "export", Dotfiles::IcePreferences::DOMAIN, "-"], empty_plist)
    @fake_system.stub_command(["pgrep", "-x", "Ice"], "123", 0)

    step.run

    assert_executed ["osascript", "-e", 'tell application id "com.jordanbaird.Ice" to quit']
    assert_executed ["open", "-b", "com.jordanbaird.Ice"]
    assert @fake_system.operations.any? { |operation| managed_write?(operation, "ShowIceIcon") }
  end

  def test_run_does_not_restart_ice_when_only_login_item_drifts
    preference_checker = Object.new
    preference_checker.define_singleton_method(:complete?) { true }
    step.instance_variable_set(:@preferences, preference_checker)

    step.run

    refute_executed ["pgrep", "-x", "Ice"]
    refute_executed ["open", "-b", "com.jordanbaird.Ice"]
    assert @fake_system.operations.any? { |operation| login_item_write?(operation, "/Applications/Ice.app") }
  end

  def test_run_leaves_stopped_ice_stopped_after_preference_changes
    @fake_system.stub_command(["defaults", "export", Dotfiles::IcePreferences::DOMAIN, "-"], empty_plist)
    @fake_system.stub_command(["pgrep", "-x", "Ice"], "", 1)

    step.run

    refute_executed ["open", "-b", "com.jordanbaird.Ice"]
  end

  def test_run_does_not_reopen_ice_when_quit_fails
    @fake_system.stub_command(["defaults", "export", Dotfiles::IcePreferences::DOMAIN, "-"], empty_plist)
    @fake_system.stub_command(["pgrep", "-x", "Ice"], "123", 0)
    command = ["osascript", "-e", 'tell application id "com.jordanbaird.Ice" to quit']
    @fake_system.stub_command(command, "not permitted", 1)

    step.run

    assert_includes step.errors, "Failed to quit Ice before changing preferences"
    refute_executed ["open", "-b", "com.jordanbaird.Ice"]
  end

  def test_run_reports_login_item_write_failure
    login_command = step.send(:login_item_path_command)
    @fake_system.stub_command(login_command, "", 1)
    write_command = step.send(:command,
      "osascript",
      "-e", 'tell application "System Events"',
      "-e", 'if exists login item "Ice" then delete login item "Ice"',
      "-e", 'make login item at end with properties {name:"Ice", path:"/Applications/Ice.app", hidden:false}',
      "-e", "end tell")
    @fake_system.stub_command(write_command, "not permitted", 1)
    preference_checker = Object.new
    preference_checker.define_singleton_method(:complete?) { true }
    step.instance_variable_set(:@preferences, preference_checker)

    step.run

    assert_includes step.errors, "Failed to configure the Ice login item"
  end

  def test_uses_user_applications_path_for_non_admin_cask_install
    @fake_system.stub_file_content(File.join(@home, "Applications", "Ice.app", "Contents", "Info.plist"), "plist")

    step.run

    assert @fake_system.operations.any? { |operation| login_item_write?(operation, "#{@home}/Applications/Ice.app") }
  end

  private

  def managed_write?(operation, key)
    operation[0] == :execute && operation[1].is_a?(Array) &&
      operation[1][0, 4] == ["defaults", "write", Dotfiles::IcePreferences::DOMAIN, key]
  end

  def login_item_write?(operation, path)
    operation[0] == :execute && operation[1].is_a?(Array) &&
      operation[1].include?(%(make login item at end with properties {name:"Ice", path:"#{path}", hidden:false}))
  end

  def empty_plist
    %(<?xml version="1.0"?><plist version="1.0"><dict/></plist>)
  end
end
