require "test_helper"
require "json"
require "open3"
require "toml-rb"

class McpConfigurationSystemTest < Minitest::Test
  def setup
    super
    @system = Dotfiles::SystemAdapter.new
    template = File.join(ENV.fetch("TMPDIR", "/tmp"), "dotfiles-mcp.XXXXXXXX")
    @home = @system.execute!(["mktemp", "-d", template]).first
  end

  def teardown
    @system.rm_rf(@home)
  end

  def test_forced_dotfile_convergence_preserves_personal_mcp_configurations
    root = File.expand_path("..", __dir__)
    @system.execute!(["ln", "-s", root, File.join(@home, ".dotfiles")])
    personal = {
      ".pi/agent/mcp-adapter.json" => {"mcpServers" => {"server-1" => {"url" => "https://executor.example/mcp"}}},
      ".config/mcp/mcp.json" => {"mcpServers" => {"personal" => {"url" => "https://personal.example/mcp"}}}
    }
    personal.each { |path, config| write_config(path, config) }
    env = isolated_environment
    config_path = env.fetch("MISE_GLOBAL_CONFIG_FILE")
    @system.mkdir_p(File.dirname(config_path))
    @system.write_file(config_path, dotfile_configuration(root))

    2.times do
      output, status = Open3.capture2e(env, "mise", "bootstrap", "dotfiles", "apply", "--force", "--yes", chdir: @home)
      assert status.success?, output
      personal.each do |path, config|
        assert_equal JSON.pretty_generate(config), @system.read_file(File.join(@home, path))
      end
      defaults = JSON.parse(@system.read_file(File.join(@home, ".agents/mcp/mcp.json")))
      assert_equal false, defaults.dig("settings", "namespaceProxyTools")
      if @system.macos?
        assert_equal ["mcp"], defaults.dig("mcpServers", "cua-driver", "args")
      else
        assert_empty defaults.fetch("mcpServers")
      end
      personal.fetch(".pi/agent/mcp-adapter.json").fetch("mcpServers")["added-later"] = {"url" => "https://later.example/mcp"}
      personal.each { |path, config| write_config(path, config) }
    end
  end

  private

  def write_config(path, config)
    destination = File.join(@home, path)
    @system.mkdir_p(File.dirname(destination))
    @system.write_file(destination, JSON.pretty_generate(config))
  end

  def dotfile_configuration(root)
    config = TomlRB.load_file(File.join(root, "files/home/.config/mise/config.toml"))
    entries = config.fetch("dotfiles").filter_map do |target, entry|
      next unless target == "~" || target.include?("mcp")
      entry = entry.merge("exclude" => entry.fetch("exclude") + [".config/mise"]) if target == "~"
      fields = entry.map { |key, value| "#{key} = #{JSON.generate(value)}" }.join(", ")
      "#{JSON.generate(target)} = { #{fields} }"
    end
    "[dotfiles]\n#{entries.join("\n")}\n"
  end

  def isolated_environment
    env = %w[CONFIG DATA STATE CACHE].to_h { |name| ["XDG_#{name}_HOME", File.join(@home, "xdg", name.downcase)] }
    env.merge!(%w[CONFIG DATA STATE CACHE].to_h { |name| ["MISE_#{name}_DIR", File.join(@home, "mise", name.downcase)] })
    env.merge("HOME" => @home, "MISE_GLOBAL_CONFIG_FILE" => File.join(@home, "mise/config.toml"), "MISE_TRUSTED_CONFIG_PATHS" => @home)
  end
end
