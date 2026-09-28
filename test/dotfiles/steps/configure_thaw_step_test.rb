require "test_helper"

class ConfigureThawStepTest < StepTestCase
  step_class Dotfiles::Step::ConfigureThawStep

  def setup
    super
    @fake_system.stub_macos
    source = Dotfiles::SystemAdapter.new.read_file(File.expand_path("../../../config/thaw.yml", __dir__))
    @fake_system.stub_file_content(File.join(@dotfiles_dir, "config", "thaw.yml"), source)
    @fake_system.stub_file_content("/Applications/Thaw.app/Contents/Info.plist", "plist")
    @fake_system.stub_command("groups", "admin staff")
  end

  def test_default_return_value_is_incomplete
    assert_incomplete
  end

  def test_depends_on_mise_managed_app_install
    assert_includes Dotfiles::Step::ConfigureThawStep.depends_on, Dotfiles::Step::InstallThawAppStep
  end

  def test_complete_and_does_not_run_when_thaw_is_not_installed
    system = FakeSystemAdapter.new
    system.stub_macos
    system.stub_command("groups", "admin staff")
    missing_thaw_step = create_step(Dotfiles::Step::ConfigureThawStep, system: system)

    assert missing_thaw_step.complete?
    refute missing_thaw_step.should_run?
    refute system.operations.any? { |op| op.first == :execute && op[1].is_a?(Array) && op[1].first == "defaults" }
  end

  def test_non_admin_does_not_configure_installed_thaw
    @fake_system.stub_command("groups", "staff")

    assert step.complete?
    refute step.should_run?
    step.run
    refute @fake_system.operations.any? { |op| op.first == :execute && op[1].is_a?(Array) && op[1].first == "osascript" }
  end

  def test_ci_does_not_configure_thaw
    with_ci do
      assert step.complete?
      refute step.should_run?
      step.run
    end

    refute @fake_system.operations.any? { |op| op.first == :execute && op[1].is_a?(Array) && op[1].first == "osascript" }
  end

  def test_run_quits_and_reopens_running_thaw_when_preferences_drift
    @fake_system.stub_command(["defaults", "export", Dotfiles::ThawPreferences::DOMAIN, "-"], empty_plist)
    @fake_system.stub_command(["pgrep", "-x", "Thaw"], "123", 0)

    step.run

    assert_executed ["osascript", "-e", 'tell application id "com.stonerl.Thaw" to quit']
    assert_executed ["open", "-b", "com.stonerl.Thaw"]
    assert @fake_system.operations.any? { |operation| managed_write?(operation, "ShowOnClick") }
  end

  def test_run_does_not_restart_thaw_when_only_login_item_drifts
    preference_checker = Object.new
    preference_checker.define_singleton_method(:complete?) { true }
    step.instance_variable_set(:@preferences, preference_checker)

    step.run

    refute_executed ["pgrep", "-x", "Thaw"]
    refute_executed ["open", "-b", "com.stonerl.Thaw"]
    assert @fake_system.operations.any? { |operation| login_item_write?(operation, "/Applications/Thaw.app") }
  end

  def test_run_leaves_stopped_thaw_stopped_after_preference_changes
    @fake_system.stub_command(["defaults", "export", Dotfiles::ThawPreferences::DOMAIN, "-"], empty_plist)
    @fake_system.stub_command(["pgrep", "-x", "Thaw"], "", 1)

    step.run

    refute_executed ["open", "-b", "com.stonerl.Thaw"]
  end

  def test_run_does_not_reopen_thaw_when_quit_fails
    @fake_system.stub_command(["defaults", "export", Dotfiles::ThawPreferences::DOMAIN, "-"], empty_plist)
    @fake_system.stub_command(["pgrep", "-x", "Thaw"], "123", 0)
    command = ["osascript", "-e", 'tell application id "com.stonerl.Thaw" to quit']
    @fake_system.stub_command(command, "not permitted", 1)

    step.run

    assert_includes step.errors, "Failed to quit Thaw before changing preferences"
    refute_executed ["open", "-b", "com.stonerl.Thaw"]
  end

  def test_run_reports_login_item_write_failure
    login_command = step.send(:login_item_path_command)
    @fake_system.stub_command(login_command, "", 1)
    write_command = step.send(:command,
      "osascript",
      "-e", 'tell application "System Events"',
      "-e", 'if exists login item "Thaw" then delete login item "Thaw"',
      "-e", 'make login item at end with properties {name:"Thaw", path:"/Applications/Thaw.app", hidden:false}',
      "-e", "end tell")
    @fake_system.stub_command(write_command, "not permitted", 1)
    preference_checker = Object.new
    preference_checker.define_singleton_method(:complete?) { true }
    step.instance_variable_set(:@preferences, preference_checker)

    step.run

    assert_includes step.errors, "Failed to configure the Thaw login item"
  end

  private

  def managed_write?(operation, key)
    operation[0] == :execute && operation[1].is_a?(Array) &&
      operation[1][0, 4] == ["defaults", "write", Dotfiles::ThawPreferences::DOMAIN, key]
  end

  def login_item_write?(operation, path)
    operation[0] == :execute && operation[1].is_a?(Array) &&
      operation[1].include?(%(make login item at end with properties {name:"Thaw", path:"#{path}", hidden:false}))
  end

  def empty_plist
    %(<?xml version="1.0"?><plist version="1.0"><dict/></plist>)
  end
end
