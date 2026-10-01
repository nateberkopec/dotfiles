# standard:disable Dotfiles/BanFileSystemClasses -- black-box tests require isolated Pi state
require "test_helper"
require "json"
require "open3"
require "tmpdir"
require "timeout"

class OpenRouterUSRuntimeTest < Minitest::Test
  INDEX = File.expand_path("../../../files/home/.pi/agent/extensions/datasafe/index.ts", __dir__)
  MODEL_A = "anthropic/claude-haiku-4.5"
  MODEL_B = "google/gemini-2.5-pro"
  BASE_URL = "https://us.openrouter.ai/api/v1"

  def setup
    flunk "required Pi runtime is missing" unless command_available?("pi")
  end

  def test_online_startup_uses_cache_then_refreshes_in_background
    with_agent_dir do |agent_dir|
      seed_stored_catalog(agent_dir)
      calls = File.join(agent_dir, "fetches.log")
      mock = write_fetch_mock(agent_dir, calls, [MODEL_A, MODEL_B])

      assert_models run_pi(agent_dir, mock: mock), [MODEL_A]
      refute File.exist?(calls), "--list-models must not fetch before displaying cached models"
      run_rpc_refresh(agent_dir, mock) do
        assert_equal [MODEL_A, MODEL_B].sort, stored_ids(agent_dir).sort
      end
      assert_includes File.readlines(calls, chomp: true), "#{BASE_URL}/models"
      assert_models run_pi(agent_dir, offline: true), [MODEL_A, MODEL_B]
    end
  end

  def test_failed_background_refresh_preserves_cached_models
    with_agent_dir do |agent_dir|
      seed_stored_catalog(agent_dir)
      calls = File.join(agent_dir, "failed.log")
      mock = write_failing_fetch_mock(agent_dir, calls)
      run_rpc_refresh(agent_dir, mock) do
        assert File.exist?(calls)
      end
      assert_models run_pi(agent_dir, offline: true), [MODEL_A]
    end
  end

  def test_cold_offline_cli_fails_closed
    with_agent_dir do |agent_dir|
      output = run_pi(agent_dir, offline: true)
      assert_models output, []
      assert_match(/No models (?:matching|available)/, output)
    end
  end

  private

  def command_available?(command)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |directory|
      File.executable?(File.join(directory, command))
    end
  end

  def with_agent_dir(&block)
    Dir.mktmpdir("openrouter-us-runtime", &block)
  end

  def seed_stored_catalog(agent_dir)
    File.write(File.join(agent_dir, "models-store.json"), JSON.generate("openrouter" => {
      "models" => [{
        "id" => MODEL_A, "name" => MODEL_A, "provider" => "openrouter", "api" => "anthropic-messages",
        "baseUrl" => BASE_URL.delete_suffix("/v1"), "reasoning" => false, "input" => ["text"],
        "cost" => {"input" => 0, "output" => 0, "cacheRead" => 0, "cacheWrite" => 0},
        "contextWindow" => 200_000, "maxTokens" => 8192
      }], "checkedAt" => 0
    }))
  end

  def stored_ids(agent_dir)
    JSON.parse(File.read(File.join(agent_dir, "models-store.json"))).fetch("openrouter").fetch("models").map { |model| model.fetch("id") }
  rescue JSON::ParserError
    []
  end

  def run_rpc_refresh(agent_dir, mock)
    env = {"OPENROUTER_API_KEY" => "runtime-test", "PI_CODING_AGENT_DIR" => agent_dir, "PI_OFFLINE" => nil}
    Open3.popen3(env, "pi", "--no-extensions", "--extension", mock, "--mode", "rpc", "--no-session") do |stdin, stdout, stderr, wait|
      begin
        Timeout.timeout(10) do
          loop do
            yield
            break
          rescue Minitest::Assertion
            raise "Pi exited before refresh: #{stderr.read}" unless wait.alive?
            sleep 0.05
          end
        end
      ensure
        stdin.close
        stdout.read
        stderr.read
      end
      assert wait.value.success?
    end
  end

  def write_failing_fetch_mock(agent_dir, calls_path)
    path = File.join(agent_dir, "failing_fetch_mock.ts")
    File.write(path, <<~TS)
      import { appendFileSync } from "node:fs";
      import openRouterUS from #{INDEX.to_json};

      globalThis.fetch = async (input) => {
        appendFileSync(#{calls_path.to_json}, `${String(input)}\n`);
        throw new Error("mock discovery failure");
      };

      export default openRouterUS;
    TS
    path
  end

  def write_fetch_mock(agent_dir, calls_path, model_ids)
    path = File.join(agent_dir, "fetch_mock_#{File.basename(calls_path, ".log")}.ts")
    File.write(path, <<~TS)
      import { appendFileSync } from "node:fs";
      import openRouterUS from #{INDEX.to_json};

      const originalFetch = globalThis.fetch;
      globalThis.fetch = async (input, init) => {
        const url = String(input);
        appendFileSync(#{calls_path.to_json}, `${url}\n`);
        if (url === #{"#{BASE_URL}/models".to_json}) {
          const ids = #{model_ids.to_json};
          return new Response(JSON.stringify({ data: ids.map((id) => ({ id })) }));
        }
        return originalFetch(input, init);
      };

      export default openRouterUS;
    TS
    path
  end

  def run_pi(agent_dir, mock: nil, offline: false)
    env = {
      "OPENROUTER_API_KEY" => "runtime-test",
      "PI_CODING_AGENT_DIR" => agent_dir,
      "PI_OFFLINE" => offline ? "1" : nil
    }
    output, status = Open3.capture2e(
      env,
      "pi", "--no-extensions", "--extension", mock || INDEX, "--list-models", "openrouter"
    )
    assert status.success?, output
    output
  end

  def assert_models(output, expected_ids)
    actual_ids = output.lines.filter_map { |line| line[/^openrouter\s+(\S+)\s/, 1] }
    assert_equal expected_ids.sort, actual_ids.sort
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
