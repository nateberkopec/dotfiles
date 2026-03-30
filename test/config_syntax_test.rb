require_relative "test_helper"
require "toml-rb"
require "json"

class ConfigSyntaxTest < Minitest::Test
  FILES_DIR = File.expand_path("../files", __dir__)

  def self.define_format_tests(glob, format)
    Dir.glob("#{FILES_DIR}/**/#{glob}", File::FNM_DOTMATCH).each do |path|
      name = path.sub("#{FILES_DIR}/", "").tr("/.", "_")
      define_method("test_#{name}_is_valid_#{format}") { send("validate_#{format}", path) }
    end
  end

  define_format_tests("*.toml", "toml")
  define_format_tests("*.{json}", "json")
  define_format_tests("*.{yaml,yml}", "yaml")

  private

  def validate_toml(path)
    TomlRB.load_file(path)
  rescue TomlRB::ParseError => e
    flunk "Invalid TOML in #{path}:\n#{e.message}"
  end

  def validate_json(path)
    content = File.read(path)
    content = content.gsub(%r{^\s*//.*$}, "").gsub(/,(\s*[}\]])/, '\1')
    JSON.parse(content)
  rescue JSON::ParserError => e
    flunk "Invalid JSON in #{path}:\n#{e.message}"
  end

  def validate_yaml(path)
    YAML.safe_load_file(path, permitted_classes: [Symbol])
  rescue Psych::SyntaxError => e
    flunk "Invalid YAML in #{path}:\n#{e.message}"
  end
end
