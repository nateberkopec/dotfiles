require "test_helper"
require "json"

class IcePreferencesTest < Minitest::Test
  def setup
    super
    @repository_path = File.join(@dotfiles_dir, "config", "ice.yml")
    @local_path = File.join(@home, ".config", "dotfiles", "ice.local.yml")
    source = Dotfiles::SystemAdapter.new.read_file(File.expand_path("../../config/ice.yml", __dir__))
    @settings = YAML.safe_load(source)
    @fake_system.stub_file_content(@repository_path, YAML.dump(@settings))
  end

  def test_default_return_value_is_incomplete
    assert_equal false, preferences.complete?
  end

  def test_complete_when_all_managed_preferences_match
    stub_export(@settings.merge("UnmanagedMachineSetting" => "preserved"))

    assert preferences.complete?
  end

  def test_local_overrides_win_without_writing_the_override_file
    @fake_system.stub_file_content(@local_path, YAML.dump("ShowIceIcon" => false))

    preferences.apply

    assert @fake_system.received_operation?(:execute,
      ["defaults", "write", Dotfiles::IcePreferences::DOMAIN, "ShowIceIcon", "-bool", "false"], quiet: true)
    refute @fake_system.operations.any? { |operation| operation.first == :write_file && operation[1] == @local_path }
  end

  def test_rejects_local_keys_outside_repository_allowlist
    @fake_system.stub_file_content(@local_path, YAML.dump("NSStatusItem Visible HItem" => false))

    error = assert_raises(ArgumentError) { preferences.complete? }

    assert_equal "Ice local overrides contain unmanaged preferences", error.message
  end

  def test_rejects_invalid_local_override_without_disclosing_its_contents
    secret = "private-app-name"
    @fake_system.stub_file_content(@local_path, "#{secret}: [")

    error = assert_raises(ArgumentError) { preferences.apply }

    assert_equal "Ice local overrides must be a valid preference mapping", error.message
    refute_includes error.message, secret
  end

  def test_current_appearance_schema_can_contain_decoder_supplied_fields
    actual = Marshal.load(Marshal.dump(@settings))
    actual["MenuBarAppearanceConfigurationV2"]["staticConfiguration"]["borderWidth"] = 1
    stub_export(actual)

    assert preferences.complete?
  end

  private

  def preferences
    @preferences ||= Dotfiles::IcePreferences.new(
      repository_path: @repository_path,
      local_path: @local_path,
      system: @fake_system
    )
  end

  def stub_export(settings)
    @fake_system.stub_command(["defaults", "export", Dotfiles::IcePreferences::DOMAIN, "-"], plist(settings))
  end

  def plist(settings)
    body = settings.map { |key, value| "<key>#{key}</key>#{plist_value(value, key)}" }.join
    %(<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>#{body}</dict></plist>)
  end

  def plist_value(value, key = nil)
    return "<data>#{[JSON.generate(value)].pack("m0")}</data>" if Dotfiles::IcePreferences::DATA_KEYS.include?(key)
    return "<dict>#{value.map { |name, _| "<key>#{name}</key><data>bnVsbA==</data>" }.join}</dict>" if key == "Hotkeys"
    case value
    when true then "<true/>"
    when false then "<false/>"
    when Integer then "<integer>#{value}</integer>"
    when Float then "<real>#{value}</real>"
    else "<string>#{value}</string>"
    end
  end
end
