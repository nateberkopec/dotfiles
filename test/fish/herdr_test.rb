require "test_helper"
require "fileutils"
require "json"
require "open3"
require "shellwords"
require "tmpdir"

class HerdrSessionsTest < Minitest::Test
  FUNCTION = File.expand_path("../../files/home/.config/fish/functions/herdr.fish", __dir__)
  FAKE = <<~'RUBY'
    #!/usr/bin/env ruby
    require "json"
    home = ENV.fetch("HOME")
    File.open(File.join(home, "calls.jsonl"), "a") { |file| file.puts JSON.generate("args" => ARGV, "state" => ENV["XDG_STATE_HOME"]) }
    exit 0 unless ARGV.first == "--session"
    running = File.join(home, "running-#{ARGV[1]}")
    case ARGV.drop(2)
    when ["server"] then File.write(running, "")
    when ["workspace", "list"] then exit(File.exist?(running) ? 0 : 1)
    end
  RUBY

  def setup
    skip "Fish is not installed" unless system("fish", "--version", out: File::NULL)
    @home = Dir.mktmpdir("herdr-fish-")
    FileUtils.mkdir_p(File.join(@home, "bin"))
    File.write(File.join(@home, "bin/herdr"), FAKE)
    FileUtils.chmod(0o755, File.join(@home, "bin/herdr"))
  end

  def teardown
    FileUtils.remove_entry(@home)
  end

  def test_bare_herdr_starts_the_default_server_cleanly_then_attaches_with_its_own_state
    calls = herdr
    server = calls.find { |call| call["args"] == ["--session", "default", "server"] }
    assert_nil server["state"]
    assert_equal [], calls.last["args"]
    assert_equal state("default"), calls.last["state"]
  end

  def test_named_session_attaches_start_that_server_and_use_its_state
    calls = herdr("--session", "work")
    assert calls.any? { |call| call["args"] == ["--session", "work", "server"] }
    assert_equal ["--session", "work"], calls.last["args"]
    assert_equal state("work"), calls.last["state"]
    calls = herdr("session", "attach", "side")
    assert calls.any? { |call| call["args"] == ["--session", "side", "server"] }
    assert_equal state("side"), calls.last["state"]
  end

  def test_running_servers_are_not_restarted
    File.write(File.join(@home, "running-work"), "")
    calls = herdr("--session=work")
    refute calls.any? { |call| call["args"].include?("server") }
    assert_equal state("work"), calls.last["state"]
  end

  def test_commands_pass_through_with_session_state_but_never_start_servers
    calls = herdr("machine", "add", "box")
    assert_equal [["machine", "add", "box"]], calls.map { |call| call["args"] }
    assert_equal state("default"), calls.last["state"]
    calls = herdr("--remote", "box", "--session", "agents")
    assert_equal [["--remote", "box", "--session", "agents"]], calls.map { |call| call["args"] }
    assert_equal state("agents"), calls.last["state"]
  end

  def test_commands_inside_a_pane_follow_that_pane_session
    socket = File.join(@home, ".config/herdr/sessions/clients/herdr.sock")
    calls = herdr("machine", "list", env: {"HERDR_ENV" => "1", "HERDR_SOCKET_PATH" => socket})
    assert_equal state("clients"), calls.last["state"]
    calls = herdr("machine", "list", env: {"HERDR_SESSION" => "personal"})
    assert_equal state("personal"), calls.last["state"]
  end

  private

  def state(session)
    File.join(@home, ".local/state/herdr-sessions", session)
  end

  def herdr(*arguments, env: {})
    FileUtils.rm_f(File.join(@home, "calls.jsonl"))
    environment = {"HOME" => @home, "PATH" => "#{@home}/bin:#{ENV.fetch("PATH")}", "XDG_STATE_HOME" => nil, "HERDR_SESSION" => nil, "HERDR_SOCKET_PATH" => nil, "HERDR_ENV" => nil}.merge(env)
    _stdout, stderr, status = Open3.capture3(environment, "fish", "--no-config", "-c", "source #{FUNCTION.shellescape}; herdr $argv", "--", *arguments)
    assert status.success?, stderr
    File.readlines(File.join(@home, "calls.jsonl")).map { |line| JSON.parse(line) }
  end
end
