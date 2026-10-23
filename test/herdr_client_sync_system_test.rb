require "test_helper"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

class HerdrClientSyncSystemTest < Minitest::Test
  PLUGIN = File.expand_path("../files/home/.local/share/dotfiles/herdr-plugins/session-template", __dir__)

  def setup
    @root = Dir.mktmpdir("herdr-client-sync-", "/tmp")
    @clients = []
    FileUtils.mkdir_p(%w[bin config sessions/personal].map { |path| File.join(@root, path) })
    FileUtils.cp(File.expand_path("fixtures/herdr_client_sync/herdr", __dir__), File.join(@root, "bin/herdr"))
    FileUtils.chmod(0o755, File.join(@root, "bin/herdr"))
    File.write(File.join(@root, "config/personal.json"), JSON.generate(workspaces: []))
    File.write(File.join(@root, "timer.mjs"), "const interval = globalThis.setInterval; globalThis.setInterval = (fn, ms) => interval(fn, ms === 300000 ? 500 : ms);\n")
  end

  def teardown
    File.write(File.join(@root, "release"), "")
    @clients.each do |input, output, errors, thread|
      input.puts 0 if thread.alive?
      thread.join(5)
      [input, output, errors].each(&:close)
    end
    sleep 0.4
    FileUtils.remove_entry(@root)
  end

  def test_sync_repeats_for_only_the_client_session_and_stops_with_the_client
    client = start_client
    wait_until { syncs.length >= 2 }
    assert syncs.all? { |call| call["session"] == "personal" && call["socket"] == File.join(@root, "sessions/personal/herdr.sock") }
    client[0].puts 42
    assert client[3].join(5), "helper kept running after its client exited"
    assert_equal 42, client[3].value.exitstatus
    assert_empty client[2].read
  end

  def test_an_action_already_started_can_finish_after_the_client_closes
    File.write(File.join(@root, "hold"), "")
    client = start_client
    wait_until { syncs.any? }
    pid = syncs.first.fetch("pid")
    refute calls.any? { |call| call["pid"] == pid && call["event"] == "finish" }
    client[0].puts 0
    assert client[3].value.success?
    File.write(File.join(@root, "release"), "")
    wait_until { calls.any? { |call| call["pid"] == pid && call["event"] == "finish" } }
    assert calls.any? { |call| call["pid"] == pid && call["event"] == "finish" }
  end

  def test_termination_stops_the_client_and_invalid_templates_are_logged_without_closing_it
    client = start_client
    wait_until { syncs.any? }
    File.write(File.join(@root, "config/personal.json"), "invalid json")
    log = File.join(@root, "plugin.log")
    wait_until { File.read(log).include?("SyntaxError") }
    assert client[3].alive?
    pid = calls.find { |call| call["args"] == ["--session", "personal"] }.fetch("pid")
    Process.kill("TERM", client[3].pid)
    assert_equal 143, client[3].value.exitstatus
    assert_raises(Errno::ESRCH) { Process.kill(0, pid) }
  end

  private

  def start_client
    env = {"PATH" => "#{@root}/bin:#{ENV.fetch("PATH")}", "FAKE_HERDR_ROOT" => @root, "FAKE_HERDR_PLUGIN" => PLUGIN, "XDG_STATE_HOME" => File.join(@root, "state"), "HERDR_SOCKET_PATH" => "/wrong/session.sock"}
    client = Open3.popen3(env, "node", "--import", File.join(@root, "timer.mjs"), File.join(PLUGIN, "client.mjs"), "personal", "--session", "personal")
    @clients << client
    client
  end

  def calls
    path = File.join(@root, "calls")
    File.exist?(path) ? File.readlines(path).map { |line| JSON.parse(line) } : []
  end

  def syncs
    calls.select { |call| call["args"] == ["workspace", "list"] && call["event"] == "start" }
  end

  def wait_until
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
    until yield
      flunk "timed out waiting for client sync" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.02
    end
  end
end
