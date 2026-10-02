require "test_helper"
require "json"
require "open3"
require "tmpdir"
require "fileutils"

class DatasafeFallbackTest < Minitest::Test
  EXTENSION = File.expand_path("../../../files/home/.pi/agent/extensions/datasafe/index.ts", __dir__)

  def test_missing_auth_for_configured_default_blocks_unrestricted_fallback
    with_pi do |dir, mock, calls|
      File.write(File.join(dir, "settings.json"), JSON.generate("defaultProvider" => "anthropic", "defaultModel" => "claude-sonnet-4-6"))
      output = pi(dir, mock, "-p", "secret", mode: "unrestricted", anthropic_key: nil)
      assert_includes output, "blocked silent model fallback from configured default anthropic/claude-sonnet-4-6"
      refute File.exist?(calls)
    end
  end

  def test_trusted_project_default_overrides_global_default
    with_pi do |dir, mock, calls|
      File.write(File.join(dir, "settings.json"), JSON.generate("defaultProvider" => "openai", "defaultModel" => "gpt-4o-mini"))
      FileUtils.mkdir_p(File.join(dir, "project", ".pi"))
      File.write(File.join(dir, "project", ".pi", "settings.json"),
        JSON.generate("defaultProvider" => "anthropic", "defaultModel" => "missing-model"))
      output = pi(dir, mock, "--approve", "-p", "secret", cwd: File.join(dir, "project"))
      assert_includes output, "blocked silent model fallback from configured default anthropic/missing-model"
      refute File.exist?(calls)
    end
  end

  def test_explicit_model_is_not_a_fallback
    with_pi do |dir, mock, calls|
      File.write(File.join(dir, "settings.json"), JSON.generate("defaultProvider" => "anthropic", "defaultModel" => "missing-model"))
      output = pi(dir, mock, "--provider", "openai", "--model", "gpt-4o-mini", "-p", "hello")
      refute_includes output, "blocked silent model fallback"
      assert_equal ["https://api.openai.com/v1/responses\n"], File.readlines(calls)
    end
  end

  def test_explicit_in_session_model_selection_unlocks_missing_default
    with_pi do |dir, mock, calls|
      File.write(File.join(dir, "settings.json"), JSON.generate("defaultProvider" => "openai", "defaultModel" => "unavailable"))
      choose = File.join(dir, "choose.ts")
      File.write(choose, <<~TS)
        export default function choose(pi) {
          pi.on("session_start", async (_event, ctx) => {
            const model = ctx.modelRegistry.getAll().find(m => m.provider === "anthropic" && m.id !== ctx.model?.id);
            if (model) await pi.setModel(model);
          });
        }
      TS
      output = pi(dir, mock, "--extension", choose, "--no-session", "-p", "hello", mode: "claude-only")
      refute_includes output, "blocked silent model fallback"
      assert_equal 1, File.readlines(calls).length
    end
  end

  def test_restoring_the_same_model_can_make_a_request
    with_pi do |dir, mock, calls|
      sessions = File.join(dir, "sessions")
      File.write(File.join(dir, "settings.json"), JSON.generate("defaultProvider" => "openai", "defaultModel" => "gpt-4o-mini"))
      pi(dir, mock, "--session-dir", sessions, "--provider", "openai", "--model", "gpt-4o-mini", "-p", "first")
      output = pi(dir, mock, "--session-dir", sessions, "--continue", "-p", "second")
      refute_includes output, "blocked silent model fallback"
      assert_equal 2, File.readlines(calls).length
    end
  end

  private

  def with_pi
    Dir.mktmpdir("datasafe-fallback") do |dir|
      calls = File.join(dir, "calls.log")
      mock = File.join(dir, "mock.ts")
      File.write(mock, <<~TS)
        import { appendFileSync } from "node:fs";
        globalThis.fetch = async (url) => {
          appendFileSync(#{calls.to_json}, String(url) + "\\n");
          return new Response("mock rejection", {status:400});
        };
        export default function mock() {}
      TS
      yield dir, mock, calls
    end
  end

  def pi(dir, mock, *args, mode: "usa-no-train", anthropic_key: "fake", cwd: nil)
    env = {"PI_CODING_AGENT_DIR" => dir, "PI_OFFLINE" => "1", "PI_DATASAFE_MODE" => mode,
           "ANTHROPIC_API_KEY" => anthropic_key, "OPENAI_API_KEY" => "fake"}
    output, = Open3.capture2e(env, "pi", "--no-extensions", "--extension", mock, "--extension", EXTENSION,
      *args, **(cwd ? {chdir: cwd} : {}))
    output
  end
end
