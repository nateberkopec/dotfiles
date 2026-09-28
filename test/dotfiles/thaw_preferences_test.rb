require "test_helper"

class ThawPreferencesTest < Minitest::Test
  def setup
    super
    @repository_path = File.join(@dotfiles_dir, "config", "thaw.yml")
    @local_path = File.join(@home, ".config", "dotfiles", "thaw.local.yml")
    source = Dotfiles::SystemAdapter.new.read_file(File.expand_path("../../config/thaw.yml", __dir__))
    @settings = YAML.safe_load(source)
    @fake_system.stub_file_content(@repository_path, YAML.dump(@settings))
  end

  def test_default_return_value_is_incomplete
    assert_equal false, preferences.complete?
  end

  def test_complete_when_all_managed_preferences_match
    stub_export(@settings.merge("UnmanagedMachineSetting" => "preserved"))

    assert preferences.complete?
    assert @fake_system.received_operation?(:execute,
      ["defaults", "export", Dotfiles::ThawPreferences::DOMAIN, "-"], quiet: true, sensitive: true)
  end

  def test_float_preferences_tolerate_defaults_rounding
    stub_export(@settings.merge("ShowOnHoverDelay" => 0.20000000298023224))

    assert preferences.complete?
  end

  def test_local_overrides_win_without_writing_the_override_file
    @fake_system.stub_file_content(@local_path, YAML.dump("ShowOnClick" => false))

    preferences.apply

    assert @fake_system.received_operation?(:execute,
      ["defaults", "write", Dotfiles::ThawPreferences::DOMAIN, "ShowOnClick", "-bool", "false"], quiet: true)
    refute @fake_system.operations.any? { |operation| operation.first == :write_file && operation[1] == @local_path }
  end

  def test_writes_integer_and_float_preferences_with_correct_types
    preferences.apply

    assert @fake_system.received_operation?(:execute,
      ["defaults", "write", Dotfiles::ThawPreferences::DOMAIN, "RehideStrategy", "-int", "0"], quiet: true)
    assert @fake_system.received_operation?(:execute,
      ["defaults", "write", Dotfiles::ThawPreferences::DOMAIN, "RehideInterval", "-float", "15.0"], quiet: true)
  end

  def test_rejects_local_keys_outside_repository_allowlist
    @fake_system.stub_file_content(@local_path, YAML.dump("NSStatusItem Visible HItem" => false))

    error = assert_raises(ArgumentError) { preferences.complete? }

    assert_equal "Thaw local overrides contain unmanaged preferences", error.message
  end

  def test_rejects_invalid_local_override_without_disclosing_its_contents
    secret = "private-app-name"
    @fake_system.stub_file_content(@local_path, "#{secret}: [")

    error = assert_raises(ArgumentError) { preferences.apply }

    assert_equal "Thaw local overrides must be a valid preference mapping", error.message
    refute_includes error.message, secret
  end

  private

  def preferences
    @preferences ||= Dotfiles::ThawPreferences.new(
      repository_path: @repository_path,
      local_path: @local_path,
      system: @fake_system
    )
  end

  def stub_export(settings)
    @fake_system.stub_command(["defaults", "export", Dotfiles::ThawPreferences::DOMAIN, "-"], plist(settings))
  end

  def plist(settings)
    body = settings.map { |key, value| "<key>#{key}</key>#{plist_value(value)}" }.join
    %(<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>#{body}</dict></plist>)
  end

  def plist_value(value)
    case value
    when true then "<true/>"
    when false then "<false/>"
    when Integer then "<integer>#{value}</integer>"
    when Float then "<real>#{value}</real>"
    else "<string>#{value}</string>"
    end
  end
end
