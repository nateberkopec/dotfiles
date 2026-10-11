require "json"

class Dotfiles::Step::ConfigurePiCuaStep < Dotfiles::Step
  DESCRIPTION = "Registers local Cua Driver with Pi's MCP adapter.".freeze

  macos_only

  def should_run?
    allowed_on_platform? && !complete?
  end

  def run
    config = configuration
    config["mcpServers"] ||= {}
    config["mcpServers"]["cua-driver"] = server
    config["settings"] ||= {}
    config["settings"].merge!(script_settings)
    @system.mkdir_p(File.dirname(config_path))
    @system.write_file(config_path, JSON.pretty_generate(config) + "\n")
  end

  def complete?
    super
    return true unless allowed_on_platform?

    config = configuration
    add_error("Pi's Cua Driver MCP registration is missing or stale") unless config.dig("mcpServers", "cua-driver") == server
    add_error("Pi's local MCP code mode is not enabled") unless script_settings.all? { |key, value| config.dig("settings", key) == value }
    errors.empty?
  end

  private

  def configuration
    return {} unless @system.file_exist?(config_path)

    JSON.parse(@system.read_file(config_path))
  end

  def server
    {"command" => File.join(@home, ".local", "share", "dotfiles", "cua-driver"), "args" => ["mcp"], "directTools" => false}
  end

  def script_settings
    {"scriptMode" => true, "scriptSkill" => "model"}
  end

  def config_path
    File.join(@home, ".pi", "agent", "mcp-adapter.json")
  end
end
