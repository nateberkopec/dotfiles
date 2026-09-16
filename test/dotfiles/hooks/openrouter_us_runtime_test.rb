# standard:disable Dotfiles/BanFileSystemClasses -- black-box tests require isolated Pi state
require "test_helper"
require "json"
require "open3"
require "tmpdir"

class OpenRouterUSRuntimeTest < Minitest::Test
  INDEX = File.expand_path("../../../files/home/.pi/agent/extensions/openrouter_us/index.ts", __dir__)
  MODEL_A = "anthropic/claude-3-haiku"
  MODEL_B = "google/gemini-2.5-pro"
  BASE_URL = "https://us.openrouter.ai/api/v1"

  def setup
    flunk "required Pi runtime is missing" unless command_available?("pi")
  end

  def test_online_cli_persists_regional_models_for_offline_startup
    with_agent_dir do |agent_dir|
      calls = File.join(agent_dir, "fetches.log")
      mock = write_fetch_mock(agent_dir, calls, [MODEL_A])

      2.times { assert_models run_pi(agent_dir, mock: mock), [MODEL_A] }
      assert_equal ["#{BASE_URL}/models"], File.readlines(calls, chomp: true)

      stored = JSON.parse(File.read(File.join(agent_dir, "models-store.json"))).fetch("openrouter")
      assert_equal [BASE_URL], stored.fetch("models").map { |model| model.fetch("baseUrl") }.uniq
      assert_models run_pi(agent_dir, offline: true), [MODEL_A]

      expire_stored_catalog(agent_dir)
      assert_models run_pi(agent_dir, offline: true), [MODEL_A]
      failing_mock = write_failing_fetch_mock(agent_dir, File.join(agent_dir, "failed.log"))
      assert_models run_pi(agent_dir, mock: failing_mock), [MODEL_A]
      assert_equal ["#{BASE_URL}/models"], File.readlines(File.join(agent_dir, "failed.log"), chomp: true)
    end
  end

  def test_online_cli_discovers_new_models_after_reload
    with_agent_dir do |agent_dir|
      first_mock = write_fetch_mock(agent_dir, File.join(agent_dir, "first.log"), [MODEL_A])
      assert_models run_pi(agent_dir, mock: first_mock), [MODEL_A]
      expire_stored_catalog(agent_dir)

      second_mock = write_fetch_mock(agent_dir, File.join(agent_dir, "second.log"), [MODEL_A, MODEL_B])
      assert_models run_pi(agent_dir, mock: second_mock), [MODEL_A, MODEL_B]
      assert_models run_pi(agent_dir, offline: true), [MODEL_A, MODEL_B]
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

  def expire_stored_catalog(agent_dir)
    path = File.join(agent_dir, "models-store.json")
    store = JSON.parse(File.read(path))
    store.fetch("openrouter")["checkedAt"] = 0
    File.write(path, JSON.generate(store))
  end

  def write_failing_fetch_mock(agent_dir, calls_path)
    path = File.join(agent_dir, "failing_fetch_mock.ts")
    File.write(path, <<~TS)
      import { appendFileSync } from "node:fs";

      export default function () {
        globalThis.fetch = async (input) => {
          appendFileSync(#{calls_path.to_json}, `${String(input)}\n`);
          throw new Error("mock discovery failure");
        };
      }
    TS
    path
  end

  def write_fetch_mock(agent_dir, calls_path, model_ids)
    path = File.join(agent_dir, "fetch_mock_#{File.basename(calls_path, ".log")}.ts")
    File.write(path, <<~TS)
      import { appendFileSync } from "node:fs";

      export default function () {
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
      }
    TS
    path
  end

  def run_pi(agent_dir, mock: nil, offline: false)
    env = {
      "OPENROUTER_API_KEY" => "runtime-test",
      "PI_CODING_AGENT_DIR" => agent_dir,
      "PI_OFFLINE" => offline ? "1" : nil
    }
    extensions = mock ? ["--extension", mock] : []
    output, status = Open3.capture2e(
      env,
      "pi", "--no-extensions", *extensions, "--extension", INDEX, "--list-models", "openrouter"
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
