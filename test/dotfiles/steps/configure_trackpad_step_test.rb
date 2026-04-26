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
