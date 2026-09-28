require "test_helper"
require "json"
require "open3"
require "tmpdir"

class DatasafeClaudeTest < Minitest::Test
  EXTENSION = File.expand_path("../../../files/home/.pi/agent/extensions/datasafe/index.ts", __dir__)

  def test_catalog_allows_first_party_anthropic_and_meridian_only
    Dir.mktmpdir("datasafe-claude") do |dir|
      integration = File.join(dir, "meridian.ts")
      File.write(integration, <<~TS)
        export default function(pi) {
          pi.registerProvider("meridian", {api:"anthropic-messages",apiKey:"fake",
            baseUrl:"http://127.0.0.1:3456",models:[{id:"claude-test",name:"Claude Test",
            reasoning:false,input:["text"],cost:{input:0,output:0,cacheRead:0,cacheWrite:0},
            contextWindow:8192,maxTokens:1024}]});
        }
      TS
      assert_match(/^anthropic\s+claude/, pi(dir, "--list-models", "anthropic"))
      assert_match(/^meridian\s+claude-test/, pi(dir, "--extension", integration, "--list-models", "meridian"))
      %w[openai openrouter fireworks vercel].each do |provider|
        refute_match(/^#{Regexp.escape(provider)}\s+/, pi(dir, "--list-models", provider))
      end
      refute_match(/^anthropic\s+claude/, pi(dir, "--list-models", "anthropic", mode: "usa-no-train"))
    end
  end

  def test_anthropic_direct_request_and_unknown_provider_selection
    Dir.mktmpdir("datasafe-claude") do |dir|
      mock = File.join(dir, "mock.ts")
      sent = File.join(dir, "sent.json")
      File.write(mock, <<~TS)
        import { writeFileSync } from "node:fs";
        globalThis.fetch = async (url, init) => {
          writeFileSync(#{sent.to_json}, JSON.stringify({url:String(url),body:init?.body}));
          return new Response(JSON.stringify({error:{message:"Mock rejection"}}), {status:400});
        };
        export default function mock() {}
      TS
      output = pi(dir, "--extension", mock, "--provider", "openai", "--model", "gpt-4o-mini", "-p", "secret")
      assert_includes output, 'Unknown provider "openai"'
      refute File.exist?(sent)
      pi(dir, "--extension", mock, "--provider", "anthropic", "--model", "claude-sonnet-4-6", "--no-tools", "--no-session", "-p", "hello")
      request = JSON.parse(File.read(sent))
      assert_match(%r{\Ahttps://api\.anthropic\.com/v1/messages}, request.fetch("url"))
      assert_equal "claude-sonnet-4-6", JSON.parse(request.fetch("body")).fetch("model")
    end
  end

  def test_missing_default_requires_explicit_model_in_claude_profile
    Dir.mktmpdir("datasafe-claude") do |dir|
      File.write(File.join(dir, "settings.json"), JSON.generate("defaultProvider" => "openai-codex", "defaultModel" => "unavailable"))
      sent = File.join(dir, "sent.log")
      mock = File.join(dir, "mock.ts")
      File.write(mock, <<~TS)
        import { writeFileSync } from "node:fs";
        globalThis.fetch = async (url) => {
          writeFileSync(#{sent.to_json}, String(url));
          return new Response("mock rejection", {status:400});
        };
        export default function mock() {}
      TS
      output = pi(dir, "--extension", mock, "--no-session", "-p", "hello")
      assert_includes output, "blocked silent model fallback from configured default openai-codex/unavailable"
      refute File.exist?(sent)
      pi(dir, "--extension", mock, "--provider", "anthropic", "--model", "claude-sonnet-4-6", "--no-session", "-p", "hello")
      assert_match(%r{\Ahttps://api\.anthropic\.com/v1/messages}, File.read(sent))
    end
  end

  def test_unknown_profile_fails_closed
    Dir.mktmpdir("datasafe-claude") do |dir|
      refute_match(/^anthropic\s+claude/, pi(dir, "--list-models", "anthropic", mode: "not-a-profile"))
    end
  end

  private

  def pi(dir, *args, mode: "claude-only")
    env = {"PI_CODING_AGENT_DIR" => dir, "PI_OFFLINE" => "1", "PI_DATASAFE_MODE" => mode,
           "ANTHROPIC_API_KEY" => "fake", "OPENAI_API_KEY" => "fake", "OPENROUTER_API_KEY" => "fake",
           "FIREWORKS_API_KEY" => "fake", "AI_GATEWAY_API_KEY" => "fake"}
    output, = Open3.capture2e(env, "pi", "--no-extensions", "--extension", EXTENSION, *args)
    output
  end
end
