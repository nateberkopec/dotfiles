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
    File.write(File.join(@root, "timer.mjs"), "const interval = globalThis.setInterval; globalThis.setInterval = (fn, ms) => interval(fn, ms === 300000 ? 40 : ms);\n")
  end

  def teardown
    @clients.each do |input, output, errors, thread|
      input.puts 0 if thread.alive?
      thread.join(5)
      [input, output, errors].each(&:close)
    end
    FileUtils.remove_entry(@root)
  end

  def test_sync_repeats_for_only_the_client_session_and_stops_with_the_client
    client = start_client
    wait_until { syncs.length >= 2 }
    assert syncs.all? { |call| call["session"] == "personal" && call["socket"] == File.join(@root, "sessions/personal/herdr.sock") }
    client[0].puts 42
    assert_equal 42, client[3].value.exitstatus
    count = syncs.length
    sleep 0.25
    assert_equal count, syncs.length
    assert_empty client[2].read
  end

  def test_multiple_clients_share_a_session_lock_and_one_can_close_without_stopping_the_other
    first, second = start_client, start_client("other-state")
    wait_until { syncs.length >= 3 }
    active = 0
    calls.select { |call| call["args"] == ["workspace", "list"] }.each do |call|
      active += (call["event"] == "start") ? 1 : -1
      assert_operator active, :<=, 1
    end
    first[0].puts 0
    assert first[3].value.success?
    count = syncs.length
    wait_until { syncs.length > count }
    assert second[3].alive?
  end

  def test_termination_stops_the_client_and_invalid_templates_are_logged_without_closing_it
    client = start_client
    wait_until { syncs.any? }
    File.write(File.join(@root, "config/personal.json"), "invalid json")
    log = File.join(@root, "state/template-sync.log")
    wait_until { File.read(log).include?("SyntaxError") }
    assert client[3].alive?
    pid = calls.find { |call| call["args"] == ["--session", "personal"] }.fetch("pid")
    Process.kill("TERM", client[3].pid)
    assert_equal 143, client[3].value.exitstatus
    assert_raises(Errno::ESRCH) { Process.kill(0, pid) }
  end

  private

  def start_client(state = "state")
    env = {"PATH" => "#{@root}/bin:#{ENV.fetch("PATH")}", "FAKE_HERDR_ROOT" => @root, "XDG_STATE_HOME" => File.join(@root, state), "HERDR_SOCKET_PATH" => "/wrong/session.sock"}
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
