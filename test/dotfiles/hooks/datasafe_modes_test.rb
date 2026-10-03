require "test_helper"
require "open3"
require "json"
require "tmpdir"

class DatasafeModesTest < Minitest::Test
  EXTENSION = File.expand_path("../../../files/home/.pi/agent/extensions/datasafe/index.ts", __dir__)

  def test_safe_catalog_hides_unapproved_provider_and_rejects_direct_selection
    Dir.mktmpdir("datasafe") do |dir|
      output = pi(dir, "--list-models", "anthropic")
      refute_match(/^anthropic\s+claude/, output)

      output = pi(dir, "--provider", "anthropic", "--model", "claude-sonnet-4-6", "-p", "hello")
      assert_includes output, 'Unknown provider "anthropic"'
      refute_includes output, "hello from provider"
    end
  end

  def test_unrestricted_catalog_exposes_unapproved_provider
    Dir.mktmpdir("datasafe") do |dir|
      output = pi(dir, "--list-models", "anthropic", mode: "unrestricted")
      assert_match(/^anthropic\s+claude/, output)
    end
  end

  def test_unknown_configured_provider_is_not_listed
    Dir.mktmpdir("datasafe") do |dir|
      File.write(File.join(dir, "models.json"), JSON.generate("providers" => {
        "unsafe" => {"baseUrl" => "https://example.invalid/v1", "apiKey" => "fake",
                     "api" => "openai-completions", "models" => [{"id" => "bad", "contextWindow" => 8192, "maxTokens" => 1024}]}
      }))
      refute_match(/^unsafe\s+bad/, pi(dir, "--list-models", "unsafe"))
      assert_match(/^unsafe\s+bad/, pi(dir, "--list-models", "unsafe", mode: "unrestricted"))
    end
  end

  def test_resuming_unavailable_model_can_use_compliant_fallback
    Dir.mktmpdir("datasafe") do |dir|
      sessions = File.join(dir, "sessions")
      calls = File.join(dir, "calls.log")
      mock = File.join(dir, "mock.ts")
      File.write(File.join(dir, "settings.json"), JSON.generate("defaultProvider" => "openai", "defaultModel" => "gpt-4o-mini"))
      File.write(mock, <<~TS)
        import { appendFileSync } from "node:fs";
        globalThis.fetch = async (url) => {
          appendFileSync(#{calls.to_json}, String(url) + "\\n");
          return new Response(JSON.stringify({error:{message:"Mock rejection"}}), {status:400});
        };
        export default function mock() {}
      TS
      env = {"PI_CODING_AGENT_DIR" => dir, "PI_OFFLINE" => "1", "ANTHROPIC_API_KEY" => "fake", "OPENAI_API_KEY" => "fake"}
      args = ["pi", "--no-extensions", "--extension", mock, "--extension", EXTENSION, "--session-dir", sessions]
      Open3.capture2e(env.merge("PI_DATASAFE_MODE" => "unrestricted"), *args,
        "--provider", "anthropic", "--model", "claude-sonnet-4-6", "-p", "secret")
      initial_calls = File.readlines(calls)
      assert_equal 1, initial_calls.length
      output, = Open3.capture2e(env.merge("PI_DATASAFE_MODE" => "usa-no-train"), *args,
        "--continue", "-p", "remember?")
      refute_includes output, "Datasafe blocked"
      assert_equal 2, File.readlines(calls).length
      assert_match(%r{\Ahttps://api\.openai\.com/}, File.readlines(calls).last)
    end
  end

  def test_missing_configured_default_can_fall_back_in_either_mode
    %w[usa-no-train unrestricted].each do |mode|
      Dir.mktmpdir("datasafe") do |dir|
        calls = File.join(dir, "calls.log")
        mock = File.join(dir, "mock.ts")
        File.write(File.join(dir, "settings.json"), JSON.generate("defaultProvider" => "anthropic", "defaultModel" => "missing-model"))
        File.write(mock, <<~TS)
          import { appendFileSync } from "node:fs";
          globalThis.fetch = async (url) => {
            appendFileSync(#{calls.to_json}, String(url) + "\\n");
            return new Response("mock rejection", {status:400});
          };
          export default function mock() {}
        TS
        output = pi(dir, "--extension", mock, "--no-session", "-p", "secret", mode: mode)
        refute_includes output, "Datasafe blocked"
        assert_equal 1, File.readlines(calls).length
      end
    end
  end

  def test_invalid_mode_fails_closed
    Dir.mktmpdir("datasafe") do |dir|
      output = pi(dir, "--list-models", "anthropic", mode: "invalid")
      refute_match(/^anthropic\s+claude/, output)
    end
  end

  private

  def pi(dir, *args, mode: nil)
    env = {"PI_CODING_AGENT_DIR" => dir, "PI_OFFLINE" => "1", "ANTHROPIC_API_KEY" => "fake",
           "PI_DATASAFE_MODE" => mode, "OPENAI_API_KEY" => "fake"}
    output, = Open3.capture2e(env, "pi", "--no-extensions", "--extension", EXTENSION, *args)
    output
  end
end
