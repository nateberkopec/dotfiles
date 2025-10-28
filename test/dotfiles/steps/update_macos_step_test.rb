require "test_helper"

class UpdateMacOSStepTest < Minitest::Test
  def setup
    super
    @step = create_step(Dotfiles::Step::UpdateMacOSStep)
    @plist_path = "/Library/Preferences/com.apple.SoftwareUpdate.plist"
    @recommended_updates_command = "defaults read #{@plist_path} RecommendedUpdates 2>/dev/null"
    @last_update_command = "defaults read #{@plist_path} LastBackgroundSuccessfulDate 2>/dev/null"
    @minor_update_output = ['Identifier = "MSU_UPDATE_123_minor"', 0]
    @no_updates_output = ["no updates", 1]
  end

  def test_should_run_returns_false_by_default
    refute @step.should_run?
  end

  def test_complete_returns_true_by_default
    assert @step.complete?
  end

  def test_should_run_returns_false_in_ci
    stub_admin_with_updates
    with_ci { refute @step.should_run? }
  end

  def test_should_run_returns_false_without_admin
    stub_updates_available
    @fake_system.stub_command_output("groups", "staff")
    refute @step.should_run?
  end

  def test_should_run_returns_false_without_updates
    stub_admin_without_updates
    refute @step.should_run?
  end

  def test_should_run_returns_true_with_admin_and_updates
    stub_admin_with_updates
    assert @step.should_run?
  end

  def test_complete_returns_true_in_ci
    stub_updates_with_last_check
    with_ci { assert @step.complete? }
  end

  def test_complete_returns_true_without_updates
    stub_no_updates_with_last_check
    assert @step.complete?
  end

  def test_complete_returns_false_with_updates
    stub_updates_with_last_check
    refute @step.complete?
  end

  private

  def stub_plist
    @fake_system.stub_file_content(@plist_path, "plist")
  end

  def stub_updates_available
    stub_plist
    @fake_system.stub_execute_result(@recommended_updates_command, @minor_update_output)
  end

  def stub_no_updates
    stub_plist
    @fake_system.stub_execute_result(@recommended_updates_command, @no_updates_output)
  end

  def stub_admin_with_updates
    @fake_system.stub_command_output("groups", "admin staff")
    stub_updates_available
  end

  def stub_admin_without_updates
    @fake_system.stub_command_output("groups", "admin staff")
    stub_no_updates
  end

  def stub_updates_with_last_check
    stub_updates_available
    @fake_system.stub_execute_result(@last_update_command, ["2024-01-01", 0])
  end

  def stub_no_updates_with_last_check
    stub_no_updates
    @fake_system.stub_execute_result(@last_update_command, ["2024-01-01", 0])
  end
end
