require "test_helper"
require "toml-rb"

class OmniWMSettingsTest < Minitest::Test
  def test_assigns_only_the_intentional_hotkeys
    assert_equal expected_hotkeys, hotkeys.reject { |_, binding| binding == "Unassigned" }
  end

  def test_disables_unused_default_hotkeys
    disabled_hotkey_ids.each do |id|
      assert_equal "Unassigned", hotkeys.fetch(id)
    end
  end

  def test_uses_monitor_specific_automatic_column_widths
    refute settings.fetch("niri").key?("defaultContainerPrimarySpan")
    assert_equal 3, visible_container_counts.fetch("DELL G3223Q")
    assert_equal 2, visible_container_counts.fetch("Built-in Retina Display")
  end

  private

  def settings
    @settings ||= TomlRB.load_file(settings_path)
  end

  def hotkeys
    @hotkeys ||= settings.fetch("hotkeys").to_h do |hotkey|
      [hotkey.fetch("id"), hotkey.fetch("binding")]
    end
  end

  def expected_hotkeys
    direct_workspaces.merge(
      "switchWorkspace.previous" => "Option+Left Bracket",
      "switchWorkspace.next" => "Option+Right Bracket",
      "moveWindowToWorkspaceUp" => "Option+Shift+Left Bracket",
      "moveWindowToWorkspaceDown" => "Option+Shift+Right Bracket",
      "workspaceBackAndForth" => "Option+Tab",
      "focus.left" => "Option+H",
      "focus.down" => "Option+J",
      "focus.up" => "Option+K",
      "focus.right" => "Option+L",
      "move.left" => "Option+Shift+H",
      "move.down" => "Option+Shift+J",
      "move.up" => "Option+Shift+K",
      "move.right" => "Option+Shift+L",
      "moveColumn.left" => "Control+Option+H",
      "moveColumn.right" => "Control+Option+L",
      "balanceSizes" => "Option+Shift+B",
      "toggleContainerFullPrimarySpan" => "Option+Shift+F",
      "toggleWorkspaceLayout" => "Hyper+T",
      "toggleFullscreen" => "Hyper+F",
      "focusMonitorNext" => "Hyper+M",
      "moveWindowToMonitor.left" => "Hyper+H",
      "moveWindowToMonitor.right" => "Hyper+L",
      "openCommandPalette" => "Hyper+Space"
    )
  end

  def direct_workspaces
    (0..8).to_h { |index| ["switchWorkspace.#{index}", "Option+#{index + 1}"] }
      .merge((0..8).to_h { |index| ["moveToWorkspace.#{index}", "Option+Shift+#{index + 1}"] })
  end

  def disabled_hotkey_ids
    %w[
      focusPrevious moveColumnToWorkspaceUp moveColumnToWorkspaceDown focusMonitorLast
      moveColumnToFirst moveColumnToLast toggleColumnTabbed focusColumnFirst focusColumnLast
      focusColumn.0 focusColumn.1 focusColumn.2 focusColumn.3 focusColumn.4 focusColumn.5
      focusColumn.6 focusColumn.7 focusColumn.8 cycleSizeForward cycleSizeBackward
      expandContainerToAvailablePrimarySpan resetWindowSecondarySpan
      setContainerPrimarySpan.decrease10Percent setContainerPrimarySpan.increase10Percent
      setWindowSecondarySpan.decrease10Percent setWindowSecondarySpan.increase10Percent
      raiseAllFloatingWindows openMenuAnywhere toggleQuakeTerminal toggleOverview
    ]
  end

  def visible_container_counts
    settings.fetch("monitorNiriOverrides").to_h do |monitor|
      [monitor.fetch("monitorName"), monitor.fetch("visibleContainerCount")]
    end
  end

  def settings_path
    File.expand_path("../files/home/.config/omniwm/settings.toml", __dir__)
  end
end
