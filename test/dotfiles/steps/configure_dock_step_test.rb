require "test_helper"

class ConfigureDockStepTest < Minitest::Test
  def test_run_applies_all_dock_settings
    step = create_step(Dotfiles::Step::ConfigureDockStep)
    stub_run
    step.run
    assert @fake_system.received_operation?(:execute, "defaults write com.apple.dock autohide -bool true", {quiet: true})
    assert @fake_system.received_operation?(:execute, "defaults write com.apple.dock orientation left", {quiet: true})
    assert @fake_system.received_operation?(:execute, "defaults write com.apple.dock persistent-apps -array", {quiet: true})
    assert @fake_system.received_operation?(:execute, "defaults write com.apple.dock autohide-delay -float 0", {quiet: true})
    assert @fake_system.received_operation?(:execute, "defaults write com.apple.dock autohide-time-modifier -float 0.4", {quiet: true})
  end

  def test_run_configures_persistent_others_and_restarts_dock
    step = create_step(Dotfiles::Step::ConfigureDockStep)
    stub_run
    step.run
    tile_data = "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>file://#{inbox_path}/</string><key>_CFURLStringType</key><integer>15</integer></dict></dict></dict>"
    assert @fake_system.received_operation?(:execute, "defaults delete com.apple.dock persistent-others 2>/dev/null || true", {quiet: true})
    assert @fake_system.received_operation?(:execute, "defaults write com.apple.dock persistent-others -array-add '#{tile_data}'", {quiet: true})
    assert @fake_system.received_operation?(:execute, "killall Dock", {quiet: true})
  end

  def test_complete_when_all_settings_match
    step = create_step(Dotfiles::Step::ConfigureDockStep)
    stub_complete_settings
    assert step.complete?
  end

  def test_incomplete_when_autohide_differs
    step = create_step(Dotfiles::Step::ConfigureDockStep)
    stub_complete_settings(autohide: "0")
    refute step.complete?
  end

  def test_incomplete_when_orientation_differs
    step = create_step(Dotfiles::Step::ConfigureDockStep)
    stub_complete_settings(orientation: "bottom")
    refute step.complete?
  end

  def test_incomplete_when_autohide_delay_differs
    step = create_step(Dotfiles::Step::ConfigureDockStep)
    stub_complete_settings(autohide_delay: "0.5")
    refute step.complete?
  end

  def test_incomplete_when_autohide_time_modifier_differs
    step = create_step(Dotfiles::Step::ConfigureDockStep)
    stub_complete_settings(autohide_time_modifier: "1.0")
    refute step.complete?
  end

  def test_incomplete_when_persistent_apps_not_empty
    step = create_step(Dotfiles::Step::ConfigureDockStep)
    stub_complete_settings(persistent_apps: "(\n    {}\n)")
    refute step.complete?
  end

  def test_incomplete_when_inbox_not_in_persistent_others
    step = create_step(Dotfiles::Step::ConfigureDockStep)
    stub_complete_settings(persistent_others: "(\n)")
    refute step.complete?
  end

  def test_incomplete_when_command_fails
    step = create_step(Dotfiles::Step::ConfigureDockStep)
    @fake_system.stub_command_output("defaults read com.apple.dock autohide", "", exit_status: 1)
    refute step.complete?
  end

  private

  def inbox_path
    "#{@home}/Documents/Inbox"
  end

  def stub_run
    @fake_system.stub_command_output("defaults delete com.apple.dock persistent-others 2>/dev/null || true", "", exit_status: 0)
  end

  def stub_complete_settings(autohide: "1", orientation: "left", autohide_delay: "0", autohide_time_modifier: "0.4", persistent_apps: "(\n)", persistent_others: nil)
    @fake_system.stub_command_output("defaults read com.apple.dock autohide", autohide, exit_status: 0)
    @fake_system.stub_command_output("defaults read com.apple.dock orientation", orientation, exit_status: 0)
    @fake_system.stub_command_output("defaults read com.apple.dock autohide-delay", autohide_delay, exit_status: 0)
    @fake_system.stub_command_output("defaults read com.apple.dock autohide-time-modifier", autohide_time_modifier, exit_status: 0)
    @fake_system.stub_command_output("defaults read com.apple.dock persistent-apps", persistent_apps, exit_status: 0)
    persistent_others ||= "(\n    {\n        \"tile-data\" =         {\n            \"file-data\" =             {\n                \"_CFURLString\" = \"file://#{inbox_path}/\";\n            };\n        };\n    }\n)"
    @fake_system.stub_command_output("defaults read com.apple.dock persistent-others", persistent_others, exit_status: 0)
  end
end
