require "yaml"

class Dotfiles::ThawPreferences
  DOMAIN = "com.stonerl.Thaw"
  FLOAT_KEYS = %w[ShowOnHoverDelay RehideInterval].freeze
  INTEGER_KEYS = %w[RehideStrategy].freeze
  FLOAT_EPSILON = 0.000001

  def initialize(repository_path:, local_path:, system:)
    @repository_path = repository_path
    @local_path = local_path
    @system = system
  end

  def complete?
    actual = exported_preferences
    preferences.all? { |key, value| matches?(actual[key], value) }
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
      raise ArgumentError, "Thaw local overrides contain unmanaged preferences" unless unknown.empty?
      baseline.merge(overrides)
    end
  end

  def load_yaml(path)
    value = YAML.safe_load(@system.read_file(path)) || {}
    raise ArgumentError, "Thaw preferences must be a mapping" unless value.is_a?(Hash)
    value
  end

  def load_local_overrides
    return {} unless @system.file_exist?(@local_path)
    load_yaml(@local_path)
  rescue Psych::Exception, ArgumentError
    raise ArgumentError, "Thaw local overrides must be a valid preference mapping"
  end

  def exported_preferences
    output, status = @system.execute(["defaults", "export", DOMAIN, "-"], sensitive: true)
    return {} unless status == 0 && !output.empty?
    Dotfiles::ThawPlist.parse(output)
  end

  def matches?(actual, expected)
    return (actual - expected).abs < FLOAT_EPSILON if actual.is_a?(Numeric) && expected.is_a?(Float)
    actual == expected
  end

  def write(key, value)
    type = if FLOAT_KEYS.include?(key)
      "-float"
    elsif INTEGER_KEYS.include?(key)
      "-int"
    else
      "-bool"
    end
    _output, status = @system.execute(["defaults", "write", DOMAIN, key, type, value.to_s])
    raise "Failed to write managed Thaw preference #{key}" unless status == 0
  end
end
