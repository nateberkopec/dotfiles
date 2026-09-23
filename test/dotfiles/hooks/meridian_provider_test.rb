# standard:disable Dotfiles/BanFileSystemClasses -- black-box test requires isolated Pi state
require "test_helper"
require "open3"
require "tmpdir"

class MeridianProviderTest < Minitest::Test
  EXTENSION = File.expand_path("../../../files/home/.pi/agent/extensions/meridian.ts", __dir__)

  def test_discovers_local_catalog_in_offline_mode_and_routes_every_model_to_loopback
    output, status = run_wrapper(<<~TS, {"PI_OFFLINE" => "1"})
      import meridian from #{EXTENSION.to_json};

      const catalog = (id) => ({
        object: "list",
        data: [{
          id,
          object: "model",
          owned_by: "anthropic",
          display_name: id === "claude-opus-4-6" ? "Known" : "New",
          context_window: 12345,
          capabilities: { image_input: { supported: true }, thinking: { supported: true } },
        }],
      });

      export default async function verify(pi) {
        let payload = catalog("claude-opus-4-6");
        globalThis.fetch = async (url) => {
          if (url !== "http://127.0.0.1:3456/v1/models") throw new Error("wrong discovery URL");
          return new Response(JSON.stringify(payload), { status: 200 });
        };
        let registered;
        await meridian({ registerProvider: (id, config) => { registered = { id, config }; } });
        if (registered.id !== "meridian") throw new Error("wrong provider id");
        if (registered.config.api !== "anthropic-messages") throw new Error("wrong API");
        if (registered.config.apiKey !== "x") throw new Error("wrong dummy key");
        if (registered.config.headers["x-meridian-agent"] !== "pi") throw new Error("missing Pi adapter header");
        if (registered.config.models[0].maxTokens === 12345) throw new Error("known model did not reuse built-in metadata");

        payload = catalog("claude-new-from-meridian");
        const refreshed = await registered.config.refreshModels({
          allowNetwork: true,
          signal: new AbortController().signal,
        });
        if (refreshed[0].id !== "claude-new-from-meridian") throw new Error("catalog change was ignored");
        if (refreshed[0].contextWindow !== 12345 || refreshed[0].maxTokens !== 12345) {
          throw new Error("new model did not use endpoint metadata");
        }
        for (const model of [...registered.config.models, ...refreshed]) {
          if (model.baseUrl !== registered.config.baseUrl) throw new Error("model escaped loopback routing");
          if (model.api !== "anthropic-messages") throw new Error("model used the wrong API");
        }
        pi.registerProvider(registered.id, { ...registered.config, models: refreshed });
      }
    TS

    assert status.success?, output
    assert_match(/^meridian\s+claude-new-from-meridian\s/, output)
  end

  def test_malformed_catalog_is_rejected
    output, status = run_wrapper(<<~TS, {}, "catalog-test")
      import { buildModels } from #{EXTENSION.to_json};

      export default function verify(pi) {
        try {
          buildModels({ object: "list", data: [{ id: "incomplete" }] }, []);
          throw new Error("malformed catalog was accepted");
        } catch (error) {
          if (!String(error).includes("Meridian returned a malformed model catalog")) throw error;
        }
        pi.registerProvider("catalog-test", {
          baseUrl: "http://127.0.0.1:3456",
          apiKey: "x",
          api: "anthropic-messages",
          models: [{
            id: "malformed-rejected",
            name: "Malformed rejected",
            reasoning: false,
            input: ["text"],
            cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
            contextWindow: 1,
            maxTokens: 1,
          }],
        });
      }
    TS

    assert status.success?, output
    assert_match(/^catalog-test\s+malformed-rejected\s/, output)
  end

  def test_endpoint_outage_does_not_break_other_providers
    output, status = run_wrapper(<<~TS, {"ANTHROPIC_API_KEY" => "test-key"}, "claude-opus-4-6")
      import meridian from #{EXTENSION.to_json};

      export default async function verify(pi) {
        globalThis.fetch = async () => { throw new Error("service unavailable"); };
        let registered;
        let notice = "";
        const originalError = console.error;
        console.error = (message) => { notice = String(message); };
        await meridian({ registerProvider: (id, config) => { registered = { id, config }; } });
        console.error = originalError;
        if (registered.config.models.length !== 0) throw new Error("outage exposed stale models");
        if (!notice.includes("Start Meridian at http://127.0.0.1:3456, then open /model to retry discovery")) {
          throw new Error("missing actionable outage notice");
        }
        pi.registerProvider(registered.id, registered.config);
      }
    TS

    assert status.success?, output
    assert_match(/^anthropic\s+claude-opus-4-6\s/, output)
    refute_match(/^meridian\s+/, output)
  end

  private

  def run_wrapper(source, env = {}, query = "meridian")
    Dir.mktmpdir("meridian-provider") do |agent_dir|
      wrapper = File.join(agent_dir, "verify_meridian.ts")
      File.write(wrapper, source)
      run_extension({"PI_OFFLINE" => nil}.merge(env).merge("PI_CODING_AGENT_DIR" => agent_dir), wrapper, query)
    end
  end

  def run_extension(env, extension = EXTENSION, query = "claude-opus-4-6")
    Open3.capture2e(
      env,
      "pi", "--no-extensions", "--extension", extension, "--list-models", query
    )
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
