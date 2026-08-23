require "test_helper"
require "toml-rb"

class OmniWMSettingsTest < Minitest::Test
  def test_preserves_unassigned_hotkey_overrides
    assert_equal "Unassigned", hotkeys.fetch("toggleFullscreen")
    assert_equal "Unassigned", hotkeys.fetch("setContainerPrimarySpan.decrease10Percent")
    assert_equal "Unassigned", hotkeys.fetch("setContainerPrimarySpan.increase10Percent")
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

  def visible_container_counts
    settings.fetch("monitorNiriOverrides").to_h do |monitor|
      [monitor.fetch("monitorName"), monitor.fetch("visibleContainerCount")]
    end
  end

  def settings_path
    File.expand_path("../files/home/.config/omniwm/settings.toml", __dir__)
  end
end
