require "test_helper"
require "toml-rb"

class OmniWMSettingsTest < Minitest::Test
  def test_preserves_unassigned_hotkey_overrides
    assert_equal "Unassigned", hotkeys.fetch("toggleFullscreen")
    assert_equal "Unassigned", hotkeys.fetch("setContainerPrimarySpan.decrease10Percent")
    assert_equal "Unassigned", hotkeys.fetch("setContainerPrimarySpan.increase10Percent")
  end

  private

  def hotkeys
    @hotkeys ||= TomlRB.load_file(settings_path).fetch("hotkeys").to_h do |hotkey|
      [hotkey.fetch("id"), hotkey.fetch("binding")]
    end
  end

  def settings_path
    File.expand_path("../files/home/.config/omniwm/settings.toml", __dir__)
  end
end
