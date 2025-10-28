require "test_helper"

class UpdateMacOSStepTest < Minitest::Test
  def setup
    super
    @step = create_step(Dotfiles::Step::UpdateMacOSStep)
  end

  def test_display_name
    assert_equal "Update macOS", Dotfiles::Step::UpdateMacOSStep.display_name
  end

  def test_should_run_returns_false_in_ci
    ENV["CI"] = "true"
    refute @step.should_run?
  ensure
    ENV.delete("CI")
  end

  def test_should_run_returns_false_without_admin
    @fake_system.stub_command_output("groups", "staff")
    refute @step.should_run?
  end

  def test_should_run_returns_false_without_updates
    @fake_system.stub_command_output("groups", "admin staff")
    @fake_system.stub_file_content("/Library/Preferences/com.apple.SoftwareUpdate.plist", "plist")
    @fake_system.stub_execute_result("defaults read /Library/Preferences/com.apple.SoftwareUpdate.plist RecommendedUpdates 2>/dev/null", ["no updates", 1])

    refute @step.should_run?
  end

  def test_should_run_returns_true_with_admin_and_updates
    @fake_system.stub_command_output("groups", "admin staff")
    @fake_system.stub_file_content("/Library/Preferences/com.apple.SoftwareUpdate.plist", "plist")
    @fake_system.stub_execute_result("defaults read /Library/Preferences/com.apple.SoftwareUpdate.plist RecommendedUpdates 2>/dev/null", ['Identifier = "MSU_UPDATE_123_minor"', 0])

    assert @step.should_run?
  end

  def test_complete_returns_true_in_ci
    ENV["CI"] = "true"
    assert @step.complete?
  ensure
    ENV.delete("CI")
  end

  def test_complete_returns_true_without_updates
    @fake_system.stub_file_content("/Library/Preferences/com.apple.SoftwareUpdate.plist", "plist")
    @fake_system.stub_execute_result("defaults read /Library/Preferences/com.apple.SoftwareUpdate.plist RecommendedUpdates 2>/dev/null", ["no updates", 1])
    @fake_system.stub_execute_result("defaults read /Library/Preferences/com.apple.SoftwareUpdate.plist LastBackgroundSuccessfulDate 2>/dev/null", ["2024-01-01", 0])

    assert @step.complete?
  end

  def test_complete_returns_false_with_updates
    @fake_system.stub_file_content("/Library/Preferences/com.apple.SoftwareUpdate.plist", "plist")
    @fake_system.stub_execute_result("defaults read /Library/Preferences/com.apple.SoftwareUpdate.plist RecommendedUpdates 2>/dev/null", ['Identifier = "MSU_UPDATE_123_minor"', 0])
    @fake_system.stub_execute_result("defaults read /Library/Preferences/com.apple.SoftwareUpdate.plist LastBackgroundSuccessfulDate 2>/dev/null", ["2024-01-01", 0])

    refute @step.complete?
  end
end
