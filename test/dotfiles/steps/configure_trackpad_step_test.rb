require "test_helper"

class ConfigureTrackpadStepTest < StepTestCase
  step_class Dotfiles::Step::ConfigureTrackpadStep

  def setup
    super
    write_config("trackpad", trackpad_config)
  end

  def test_run_writes_all_trackpad_defaults
    step.run
    assert_defaults_written(trackpad_entries)
  end

  def test_complete_when_all_settings_match
    stub_defaults_for_trackpad
    assert_complete
  end

  def test_incomplete_when_any_setting_differs
    stub_defaults_for_trackpad(
      overrides: {
        "com.apple.AppleMultitouchTrackpad" => {"Clicking" => 1}
      }
    )
    assert_incomplete
  end

  def test_incomplete_when_setting_command_fails
    stub_defaults_for_trackpad(status_overrides: {["com.apple.AppleMultitouchTrackpad", "Clicking"] => 1})
    assert_incomplete
  end

  def test_update_writes_current_defaults_to_config
    overrides = {
      "com.apple.AppleMultitouchTrackpad" => {
        "Clicking" => 1,
        "TrackpadRightClick" => 0,
        "FirstClickThreshold" => 2
      },
      "NSGlobalDomain" => {"com.apple.mouse.scaling" => 3}
    }
    stub_defaults_for_trackpad(overrides: overrides)

    step.update

    expect_config_write("trackpad") do |config|
      trackpad_settings = config.fetch("trackpad_settings")
      assert_equal 1, trackpad_settings["com.apple.AppleMultitouchTrackpad"]["Clicking"]
      assert_equal 0, trackpad_settings["com.apple.AppleMultitouchTrackpad"]["TrackpadRightClick"]
      assert_equal 2, trackpad_settings["com.apple.AppleMultitouchTrackpad"]["FirstClickThreshold"]
      assert_equal 3, trackpad_settings["NSGlobalDomain"]["com.apple.mouse.scaling"]
    end
  end

  def test_update_only_requests_existing_keys
    stub_defaults_for_trackpad
    step.update
    assert_defaults_read_count(trackpad_entries.size)
  end

  private

  def trackpad_config
    {
      "trackpad_settings" => {
        "com.apple.AppleMultitouchTrackpad" => {
          "Clicking" => 0,
          "TrackpadRightClick" => 1,
          "FirstClickThreshold" => 1
        },
        "NSGlobalDomain" => {
          "com.apple.mouse.scaling" => 2
        }
      }
    }
  end

  def trackpad_entries
    @trackpad_entries ||= flatten_defaults_config(trackpad_config["trackpad_settings"])
  end

  def stub_defaults_for_trackpad(overrides: {}, status_overrides: {})
    stub_defaults(trackpad_entries, overrides: overrides, status_overrides: status_overrides)
  end
end
