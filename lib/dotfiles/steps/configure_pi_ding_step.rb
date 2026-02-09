require "json"

class Dotfiles::Step::ConfigurePiDingStep < Dotfiles::Step
  def self.depends_on
    [Dotfiles::Step::SyncHomeDirectoryStep]
  end

  def self.display_name
    "Pi Ding"
  end

  def run
    settings = load_settings
    return unless settings

    original = JSON.parse(JSON.generate(settings))
    ensure_package_enabled(settings)
    ensure_ding_config(settings)

    return if settings == original

    @system.mkdir_p(File.dirname(settings_path))
    @system.write_file(settings_path, JSON.pretty_generate(settings) + "\n")
  end

  def complete?
    super

    settings = load_settings
    return false unless settings

    packages = settings["packages"]
    add_error("pi settings missing packages array") unless packages.is_a?(Array)
    add_error("pi-ding not enabled in pi packages") unless packages.is_a?(Array) && package_enabled?(packages)

    ding = settings["ding"]
    add_error("pi settings missing ding config") unless ding.is_a?(Hash)
    add_error("pi-ding disabled") unless ding.is_a?(Hash) && ding["enabled"] == true

    @errors.empty?
  end

  private

  def settings_path
    File.join(@home, ".pi", "agent", "settings.json")
  end

  def ding_template_path
    File.join(@dotfiles_dir, "files", "home", ".pi", "agent", "ding.json")
  end

  def load_settings
    return {} unless @system.file_exist?(settings_path)

    JSON.parse(@system.read_file(settings_path))
  rescue JSON::ParserError => e
    add_error("Invalid JSON in #{collapse_path_to_home(settings_path)}: #{e.message}")
    nil
  rescue Errno::ENOENT
    {}
  end

  def package_enabled?(packages)
    packages.any? { |entry| entry.is_a?(String) && entry == "npm:pi-ding" }
  end

  def ensure_package_enabled(settings)
    settings["packages"] = [] unless settings["packages"].is_a?(Array)
    settings["packages"] << "npm:pi-ding" unless package_enabled?(settings["packages"])
  end

  def default_ding_config
    return {"enabled" => true} unless @system.macos?
    {"enabled" => true, "player" => "afplay", "path" => "/System/Library/Sounds/Glass.aiff"}
  end

  def template_ding_config
    return nil unless @system.file_exist?(ding_template_path)

    parsed = JSON.parse(@system.read_file(ding_template_path))
    parsed.is_a?(Hash) ? parsed : nil
  rescue JSON::ParserError
    nil
  end

  def ensure_ding_config(settings)
    current = settings["ding"].is_a?(Hash) ? settings["ding"] : {}
    desired = template_ding_config || default_ding_config

    merged = desired.merge(current)
    merged["enabled"] = true

    settings["ding"] = merged
  end
end
