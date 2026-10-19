require "test_helper"
require "json"
require "open3"
require "socket"
require "timeout"
require "toml-rb"

class HerdrPluginStartupSystemTest < Minitest::Test
  PLUGINS = File.expand_path("../files/home/.local/share/dotfiles/herdr-plugins", __dir__)
  HERDR = File.expand_path("fixtures/herdr_plugin_startup/herdr.mjs", __dir__)

  def setup
    @system = Dotfiles::SystemAdapter.new
    @root = @system.execute!(["mktemp", "-d", "/tmp/herdr-plugin.XXXXXXXX"]).first
    %w[bin config state].each { |name| @system.mkdir_p(File.join(@root, name)) }
    mise = @system.execute!(["which", "mise"]).first
    @system.execute!(["ln", "-s", mise, File.join(@root, "bin/mise")])
    @socket = File.join(@root, "herdr.sock")
    @server = UNIXServer.new(@socket)
    @subscriptions = Queue.new
    @thread = Thread.new { serve }
  end

  def teardown
    @server.close
    @thread.join(2)
    @system.rm_rf(@root)
  end

  def test_workspace_prefix_hooks_populate_titles_without_node_on_path
    commands("workspace-prefix").each do |command|
      run_plugin("workspace-prefix", command)
      title = JSON.parse(@system.readlines(File.join(@root, "state/metadata.jsonl")).last).last
      assert_equal "workspace_agent_title=[TES] Startup task", title
      Timeout.timeout(5) do
        assert_equal "events.subscribe", @subscriptions.pop.fetch("method")
        sleep 0.01 until @system.glob(File.join(@root, "state/watcher-*")).empty?
      end
    end
  end

  def test_session_template_hooks_start_without_node_on_path
    commands("session-template").each do |command|
      run_plugin("session-template", command)
    end
  end

  private

  def commands(plugin)
    manifest = TomlRB.load_file(File.join(PLUGINS, plugin, "herdr-plugin.toml"))
    %w[startup actions events].flat_map { |key| manifest.fetch(key, []).map { |entry| entry.fetch("command") } }
  end

  def run_plugin(plugin, command)
    env = {
      "PATH" => File.join(@root, "bin"),
      "HERDR_BIN_PATH" => HERDR,
      "HERDR_PLUGIN_CONFIG_DIR" => File.join(@root, "config"),
      "HERDR_PLUGIN_STATE_DIR" => File.join(@root, "state"),
      "HERDR_SOCKET_PATH" => @socket
    }
    _stdout, stderr, status = Open3.capture3(env, *command, chdir: File.join(PLUGINS, plugin))
    assert status.success?, stderr
  rescue Errno::ENOENT => error
    flunk "#{plugin}: #{error.message}"
  end

  def serve
    loop do
      client = @server.accept
      @subscriptions << JSON.parse(client.gets)
      client.close
    end
  rescue IOError, Errno::EBADF
    nil
  end
end
