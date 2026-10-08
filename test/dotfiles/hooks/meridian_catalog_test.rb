require "test_helper"
require_relative "../../support/meridian_extension_helper"

class MeridianCatalogTest < Minitest::Test
  include MeridianExtensionHelper

  def test_catalog_authority_and_thinking_capabilities_for_known_and_new_models
    verify_contract(<<~TS)
      import { buildModels } from #{EXTENSION.to_json};
      import { getSupportedThinkingLevels } from "@earendil-works/pi-ai";
      async function check() {
        const known = { id: "known", contextWindow: 1000000, maxTokens: 64000, reasoning: true,
          input: ["text", "image"], cost: { input: 1, output: 2, cacheRead: 3, cacheWrite: 4 },
          compat: { supportsMidConvoEffort: true }, inputLimits: { maxRequestBytes: 1234 } };
        const entry = { id: "known", object: "model", owned_by: "anthropic", display_name: "Known",
          context_window: 200000, capabilities: {
            image_input: { supported: false },
            thinking: { supported: true, types: { adaptive: { supported: true }, enabled: { supported: true } } },
            effort: { low: { supported: true }, medium: { supported: true }, high: { supported: true },
              xhigh: { supported: false }, max: { supported: true } },
          } };
        const catalog = { object: "list", data: [entry] };
        const model = buildModels(catalog, [known])[0];
        assert.equal(model.contextWindow, 200000);
        assert.equal(model.maxTokens, 64000);
        assert.deepEqual(model.input, ["text"]);
        assert.deepEqual(model.cost, known.cost);
        assert.deepEqual(model.inputLimits, known.inputLimits);
        assert.equal(model.compat.forceAdaptiveThinking, true);
        assert.equal(model.compat.supportsMidConvoEffort, true);
        assert.deepEqual(getSupportedThinkingLevels(model), ["off", "minimal", "low", "medium", "high", "max"]);
        assert.equal(model.thinkingLevelMap.max, "max");
        assert.equal(model.thinkingLevelMap.minimal, "low");
        assert.equal(known.contextWindow, 1000000);
        entry.id = "new";
        entry.capabilities.thinking.types.enabled.supported = false;
        const newer = buildModels(catalog, [known])[0];
        assert.equal(newer.compat.forceAdaptiveThinking, true);
        assert.equal(newer.thinkingLevelMap.off, null);
        assert.deepEqual(getSupportedThinkingLevels(newer), ["minimal", "low", "medium", "high", "max"]);
        entry.capabilities.thinking.supported = false;
        assert.deepEqual(getSupportedThinkingLevels(buildModels(catalog, [known])[0]), ["off"]);
        entry.id = "known";
        entry.capabilities = {};
        assert.equal(buildModels(catalog, [known])[0].reasoning, true);
        assert.deepEqual(buildModels(catalog, [known])[0].input, known.input);
        assert.throws(() => buildModels({ object: "list", data: [entry, entry] }, []), /duplicate/);
        entry.context_window = Number.MAX_SAFE_INTEGER + 1;
        assert.throws(() => buildModels(catalog, []), /malformed/);
      }
    TS
  end
end
