require "test_helper"
require "fileutils"
require "json"
require "open3"
require "socket"
require "tmpdir"

class HerdrSessionTemplateTest < Minitest::Test
  PLUGIN = File.expand_path("../files/home/.local/share/dotfiles/herdr-plugins/session-template/index.mjs", __dir__)
  FAKE_HERDR = File.expand_path("fixtures/herdr_session_template/herdr", __dir__)

  def setup
    @root = Dir.mktmpdir("hst", "/tmp")
    @home, @config, @state = %w[home config state].map { |name| File.join(@root, name) }
    FileUtils.mkdir_p([@config, @state, File.join(@root, "sessions/p")] + %w[gtd dotfiles tries].map { |name| File.join(@home, name) })
    @socket = File.join(@root, "sessions/p/herdr.sock")
    @server = UNIXServer.new(@socket)
    @thread = Thread.new { serve }
  end

  def teardown
    @server.close
    @thread.join(2)
    FileUtils.remove_entry(@root)
  end

  def test_creates_templated_workspaces_in_order_without_taking_focus
    template(workspaces: [{label: "GTD", cwd: "~/gtd"}, {label: "Dotfiles", cwd: "~/dotfiles"}])
    output = run_plugin
    assert_equal ["GTD", "Dotfiles"], labels
    assert_equal ["#{@home}/gtd", "#{@home}/dotfiles"], workspaces.map { |space| space["cwd"] }
    assert_includes output, "session-template[p]: created GTD"
    assert creates.all? { |call| call.include?("--no-focus") }
  end

  def test_fills_in_missing_workspaces_and_keeps_template_order_ahead_of_extras
    write_workspaces([{"workspace_id" => "w1", "label" => "Extra"}, {"workspace_id" => "w2", "label" => "Dotfiles"}])
    template(workspaces: [{label: "GTD", cwd: "~/gtd"}, {label: "Dotfiles", cwd: "~/dotfiles"}])
    run_plugin
    assert_equal ["GTD", "Dotfiles", "Extra"], labels
    assert_equal 1, creates.length
    run_plugin
    assert_equal 1, creates.length
  end

  def test_does_nothing_without_a_template
    run_plugin
    assert_empty calls
  end

  def test_runs_an_executable_template
    script = File.join(@config, "p")
    File.write(script, "#!/bin/sh\necho '{\"workspaces\":[{\"label\":\"Try\",\"cwd\":\"#{@home}/tries\"}]}'\n")
    FileUtils.chmod(0o755, script)
    run_plugin
    assert_equal ["Try"], labels
  end

  def test_skips_missing_directories_and_ambiguous_labels
    write_workspaces([{"workspace_id" => "w1", "label" => "GTD"}, {"workspace_id" => "w2", "label" => "GTD"}])
    template(workspaces: [{label: "GTD", cwd: "~/gtd"}, {label: "Nope", cwd: "~/missing"}, {label: "Try", cwd: "~/tries"}])
    output = run_plugin
    assert_includes output, "skipping Nope: missing directory"
    assert_includes output, "skipping GTD: 2 workspaces share that label"
    assert_equal ["Try", "GTD", "GTD"], labels
  end

  private

  def serve
    loop do
      client = @server.accept
      request = JSON.parse(client.gets)
      client.puts JSON.generate(id: request["id"], result: move(request))
      client.close
    end
  rescue IOError, Errno::EBADF
    nil
  end

  def move(request)
    raise "unexpected #{request["method"]}" unless request["method"] == "workspace.move"
    spaces = workspaces
    moved = spaces.delete_at(spaces.index { |space| space["workspace_id"] == request.dig("params", "workspace_id") })
    spaces.insert(request.dig("params", "insert_index"), moved)
    write_workspaces(spaces)
    {}
  end

  def run_plugin
    env = {"HOME" => @home, "HERDR_SOCKET_PATH" => @socket, "HERDR_BIN_PATH" => FAKE_HERDR, "HERDR_PLUGIN_CONFIG_DIR" => @config, "FAKE_HERDR_STATE" => @state}
    stdout, stderr, status = Open3.capture3(env, "node", PLUGIN)
    assert status.success?, stderr
    stdout
  end

  def template(content)
    File.write(File.join(@config, "p.json"), JSON.generate(content))
  end

  def workspaces
    path = File.join(@state, "workspaces.json")
    File.exist?(path) ? JSON.parse(File.read(path)) : []
  end

  def write_workspaces(spaces)
    File.write(File.join(@state, "workspaces.json"), JSON.generate(spaces))
  end

  def labels
    workspaces.map { |space| space["label"] }
  end

  def calls
    path = File.join(@state, "calls.jsonl")
    File.exist?(path) ? File.readlines(path).map { |line| JSON.parse(line) } : []
  end

  def creates
    calls.select { |call| call.first(2) == %w[workspace create] }
  end
end
