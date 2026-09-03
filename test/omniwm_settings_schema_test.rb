require "test_helper"

# OmniWM 0.6.4 rejects settings.toml outright when any key of its schema is
# missing or when the hotkey list does not name every assignable action exactly
# once, quarantining the file as settings.toml.corrupt and regenerating defaults.
# The fixture lists the key paths and action IDs the pinned version requires.
class OmniWMSettingsSchemaTest < Minitest::Test
  include OmniWMSettingsHelper

  def test_uses_the_settings_schema_version_omniwm_supports
    assert_equal 1, settings.fetch("schemaVersion")
  end

  def test_declares_every_setting_omniwm_requires
    assert_empty required_paths.reject { |path| declared?(path) }
  end

  def test_binds_every_assignable_action_exactly_once
    assert_equal required_hotkey_ids.sort, settings.fetch("hotkeys").map { |hotkey| hotkey.fetch("id") }.sort
  end

  private

  def declared?(path)
    !path.split(".").reduce(settings) { |node, key| node.is_a?(Hash) ? node[key] : nil }.nil?
  end

  def required_paths
    required_keys.reject { |key| key.start_with?("hotkeys.") }
  end

  def required_hotkey_ids
    required_keys.filter_map { |key| key.delete_prefix("hotkeys.") if key.start_with?("hotkeys.") }
  end

  def required_keys
    @required_keys ||= Dotfiles::SystemAdapter.new.read_file(File.join(@fixtures_dir, "omniwm", "required_settings_keys.txt")).lines(chomp: true)
  end
end
