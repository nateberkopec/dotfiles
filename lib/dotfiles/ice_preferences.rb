require "json"
require "yaml"

class Dotfiles::IcePreferences
  DOMAIN = "com.jordanbaird.Ice"
  DATA_KEYS = %w[IceIcon MenuBarAppearanceConfigurationV2].freeze
  FLOAT_KEYS = %w[ShowOnHoverDelay ItemSpacingOffset RehideInterval TempShowInterval].freeze
  INTEGER_KEYS = %w[IceBarLocation RehideStrategy].freeze

  def initialize(repository_path:, local_path:, system:)
    @repository_path = repository_path
    @local_path = local_path
    @system = system
  end

  def complete?
    actual = exported_preferences
    preferences.all? { |key, value| matches?(actual[key], value, key) }
  rescue REXML::ParseException
    false
  end

  def apply
    preferences.each { |key, value| write(key, value) }
  end

  private

  def preferences
    @preferences ||= begin
      baseline = load_yaml(@repository_path)
      overrides = load_local_overrides
      unknown = overrides.keys - baseline.keys
      raise ArgumentError, "Ice local overrides contain unmanaged preferences" unless unknown.empty?
      baseline.merge(overrides)
    end
  end

  def load_yaml(path)
    value = YAML.safe_load(@system.read_file(path)) || {}
    raise ArgumentError, "Ice preferences must be a mapping" unless value.is_a?(Hash)
    value
  end

  def load_local_overrides
    return {} unless @system.file_exist?(@local_path)
    load_yaml(@local_path)
  rescue Psych::Exception, ArgumentError
    raise ArgumentError, "Ice local overrides must be a valid preference mapping"
  end

  def exported_preferences
    output, status = @system.execute(["defaults", "export", DOMAIN, "-"])
    return {} unless status == 0 && !output.empty?
    Dotfiles::IcePlist.parse(output)
  end

  def matches?(actual, expected, key)
    return hotkeys_match?(actual, expected) if key == "Hotkeys"
    return json_subset?(JSON.parse(actual), expected) if DATA_KEYS.include?(key) && actual.is_a?(String)
    actual == expected
  rescue JSON::ParserError
    false
  end

  def hotkeys_match?(actual, expected)
    actual.is_a?(Hash) && actual.keys.sort == expected.keys.sort && actual.values.all? { |value| value == "null" }
  end

  def json_subset?(actual, expected)
    return actual == expected unless expected.is_a?(Hash) && actual.is_a?(Hash)
    expected.all? { |key, value| actual.key?(key) && json_subset?(actual[key], value) }
  end

  def write(key, value)
    command = ["defaults", "write", DOMAIN, key, *write_arguments(key, value)]
    _output, status = @system.execute(command)
    raise "Failed to write managed Ice preference #{key}" unless status == 0
  end

  def write_arguments(key, value)
    return ["-data", JSON.generate(value).unpack1("H*")] if DATA_KEYS.include?(key)
    return ["-dict", *value.flat_map { |name, _| [name, "-data", "6e756c6c"] }] if key == "Hotkeys"
    return ["-float", value.to_s] if FLOAT_KEYS.include?(key)
    return ["-int", value.to_s] if INTEGER_KEYS.include?(key)
    ["-bool", value.to_s]
  end
end
