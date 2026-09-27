# standard:disable Dotfiles/BanFileSystemClasses -- exercise Pi requests with isolated agent state
require "test_helper"
require "json"
require "open3"
require "tmpdir"

class NoTrainingExtensionsTest < Minitest::Test
  OPENROUTER = File.expand_path("../../../files/home/.pi/agent/extensions/openrouter_us/index.ts", __dir__)
  VERCEL = File.expand_path("../../../files/home/.pi/agent/extensions/vercel_us.ts", __dir__)

  def test_openrouter_request_preserves_routing_and_denies_collection
    request = capture_request(OPENROUTER, "openrouter", "anthropic/claude-3-haiku", {
      provider: {order: ["anthropic"], data_collection: "allow"}
    })

    assert_equal "deny", request.fetch("provider").fetch("data_collection")
    assert_equal ["anthropic"], request.fetch("provider").fetch("order")
  end

  def test_vercel_request_preserves_options_and_disallows_training
    request = capture_request(VERCEL, "vercel-ai-gateway", "anthropic/claude-3-haiku", {
      providerOptions: {gateway: {order: ["anthropic"], disallowPromptTraining: false}}
    })

    gateway = request.fetch("providerOptions").fetch("gateway")
    assert_equal true, gateway.fetch("disallowPromptTraining")
    assert_equal({"scope" => "zone", "geoRegion" => "us"}, gateway.fetch("inferenceRegion"))
    assert_equal ["anthropic"], gateway.fetch("order")
  end

  private

  def capture_request(extension, provider, model, initial)
    Dir.mktmpdir("no-training-test") do |dir|
      script = File.join(dir, "probe.ts")
      result = File.join(dir, "request.json")
      sent = File.join(dir, "sent.json")
      File.write(script, <<~TS)
        import { writeFileSync } from "node:fs";
        import extension from #{extension.to_json};

        globalThis.fetch = async (input, init) => {
          if (String(input).endsWith("/models")) {
            return new Response(JSON.stringify({ data: [{ id: #{model.to_json} }] }));
          }
          writeFileSync(#{sent.to_json}, String(init?.body ?? ""));
          return new Response(JSON.stringify({ error: { message: "No compliant providers available" } }), { status: 400 });
        };

        export default async function(pi) {
          pi.on("before_provider_request", (event, ctx) => {
            if (ctx.model?.provider !== #{provider.to_json}) return;
            return { ...event.payload, ...#{initial.to_json} };
          });
          await extension(pi);
          pi.on("before_provider_request", (event, ctx) => {
            if (ctx.model?.provider !== #{provider.to_json}) return;
            const payload = event.payload;
            writeFileSync(#{result.to_json}, JSON.stringify(payload));
          });
        }
      TS
      # The probe sees the final provider payload, not the helper's return in isolation.
      env = {"PI_CODING_AGENT_DIR" => dir, "PI_OFFLINE" => "1", "OPENROUTER_API_KEY" => "test", "AI_GATEWAY_API_KEY" => "test"}
      # Supply a minimal model catalog for cold offline OpenRouter startup.
      if provider == "openrouter"
        File.write(File.join(dir, "models-store.json"), JSON.generate("openrouter" => {
          "models" => [{"id" => model, "baseUrl" => "https://us.openrouter.ai/api/v1"}], "checkedAt" => 1
        }))
      end
      stdout, stderr, = Open3.capture3(env, "pi", "--no-extensions", "--extension", script,
        "--provider", provider, "--model", model, "--no-tools", "--no-session", "-p", "hello")
      assert File.exist?(result), "request not captured: #{stdout} #{stderr}"
      assert File.exist?(sent), "outgoing request not captured: #{stdout} #{stderr}"
      assert_includes stdout + stderr, "No compliant providers available"
      assert_equal JSON.parse(File.read(result)), JSON.parse(File.read(sent))
      JSON.parse(File.read(sent))
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
