require "test_helper"

class ConfigureScreenshotsStepTest < StepTestCase
  step_class Dotfiles::Step::ConfigureScreenshotsStep

  def setup
    super
    write_config("screenshots", screenshot_config)
  end

  def test_run_sets_location_and_restarts_ui_server
    step.run

    assert_executed("defaults write com.apple.screencapture location -string ~/Documents/Inbox")
    assert_executed("killall SystemUIServer")
  end

  def test_complete_when_location_matches
    stub_location("~/Documents/Inbox")
    assert_complete
  end

  def test_incomplete_when_location_differs
    stub_location("~/Desktop")
    assert_incomplete
  end

  def test_incomplete_when_read_command_fails
    stub_location("", status: 1)
    assert_incomplete
  end

  def test_update_persists_current_location_to_config
    stub_location("~/Documents/Screenshots")
    step.update

    expect_config_write("screenshots") do |config|
      assert_equal "~/Documents/Screenshots", config.dig("screenshot_settings", "com.apple.screencapture", "location")
    end
  end

  private

  def screenshot_config
    {
      "screenshot_settings" => {
        "com.apple.screencapture" => {
          "location" => "~/Documents/Inbox"
        }
      }
    }
  end

  def stub_location(value, status: 0)
    normalized = (value.is_a?(String) && value.start_with?("~/")) ? File.join(@home, value.delete_prefix("~/")) : value
    @fake_system.stub_command("defaults read com.apple.screencapture location", normalized, exit_status: status)
  end
end
