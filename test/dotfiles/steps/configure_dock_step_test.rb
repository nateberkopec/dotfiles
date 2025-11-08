require "test_helper"

class ConfigureDockStepTest < StepTestCase
  step_class Dotfiles::Step::ConfigureDockStep

  def test_run_applies_all_dock_settings
    step.run

    assert_executed("defaults write com.apple.dock autohide -bool true")
    assert_executed("defaults write com.apple.dock orientation left")
    assert_executed("defaults write com.apple.dock persistent-apps -array")
    assert_executed("defaults write com.apple.dock autohide-delay -float 0")
    assert_executed("defaults write com.apple.dock autohide-time-modifier -float 0.4")
  end

  def test_run_configures_persistent_others_and_restarts_dock
    step.run

    assert_executed("defaults delete com.apple.dock persistent-others 2>/dev/null || true")
    assert_executed("defaults write com.apple.dock persistent-others -array-add '#{dock_tile_data}'")
    assert_executed("killall Dock")
  end

  def test_complete_when_all_settings_match
    stub_complete_settings
    assert_complete
  end

  def test_incomplete_when_autohide_differs
    stub_complete_settings(autohide: "0")
    assert_incomplete
  end

  def test_incomplete_when_orientation_differs
    stub_complete_settings(orientation: "bottom")
    assert_incomplete
  end

  def test_incomplete_when_autohide_delay_differs
    stub_complete_settings(autohide_delay: "0.5")
    assert_incomplete
  end

  def test_incomplete_when_autohide_time_modifier_differs
    stub_complete_settings(autohide_time_modifier: "1.0")
    assert_incomplete
  end

  def test_incomplete_when_persistent_apps_not_empty
    stub_complete_settings(persistent_apps: "(\n    {}\n)")
    assert_incomplete
  end

  def test_incomplete_when_inbox_not_in_persistent_others
    stub_complete_settings(persistent_others: "(\n)")
    assert_incomplete
  end

  def test_incomplete_when_command_fails
    @fake_system.stub_command(defaults_read_command("com.apple.dock", "autohide"), "", exit_status: 1)
    assert_incomplete
  end

  private

  def dock_tile_data
    "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>file://#{inbox_path}/</string><key>_CFURLStringType</key><integer>15</integer></dict></dict></dict>"
  end

  def inbox_path
    File.join(@home, "Documents", "Inbox")
  end

  def stub_complete_settings(autohide: "1", orientation: "left", autohide_delay: "0", autohide_time_modifier: "0.4", persistent_apps: "(\n)", persistent_others: nil)
    values = {
      "autohide" => autohide,
      "orientation" => orientation,
      "autohide-delay" => autohide_delay,
      "autohide-time-modifier" => autohide_time_modifier,
      "persistent-apps" => persistent_apps,
      "persistent-others" => persistent_others || persistent_others_payload
    }
    stub_defaults_reads("com.apple.dock", values)
  end

  def persistent_others_payload
    "(\n    {\n        \"tile-data\" =         {\n            \"file-data\" =             {\n                \"_CFURLString\" = \"file://#{inbox_path}/\";\n            };\n        };\n    }\n)"
  end
end
