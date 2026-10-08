require "test_helper"
require_relative "../../support/meridian_extension_helper"

class MeridianCacheTest < Minitest::Test
  include MeridianExtensionHelper

  def test_cached_catalog_validation_expiry_and_rebuild_with_current_metadata
    verify_contract(<<~TS)
      import { readFileSync, writeFileSync, readdirSync } from "node:fs";
      import { join, dirname } from "node:path";
      import { catalogCachePath, readCatalogCache, writeCatalogCache, CACHE_TTL_MS } from #{"#{HELPERS}/cache.ts".to_json};
      async function check() {
        const path = catalogCachePath();
        assert.ok(path.startsWith(process.env.PI_CODING_AGENT_DIR));
        const catalog = { object: "list", data: [{ id: "known", object: "model", owned_by: "anthropic",
          display_name: "Known", context_window: 200000, capabilities: {} }] };
        const now = 1000000000;
        writeCatalogCache(catalog, path, now);
        assert.equal(readCatalogCache([{ id: "known", maxTokens: 1234 }], path, now)[0].maxTokens, 1234);
        assert.equal(readCatalogCache([{ id: "known", maxTokens: 5678 }], path, now)[0].maxTokens, 5678);
        assert.deepEqual(readCatalogCache([], path, now - 1), []);
        assert.deepEqual(readCatalogCache([], path, now + CACHE_TTL_MS + 1), []);
        const cached = JSON.parse(readFileSync(path, "utf8"));
        writeFileSync(path, JSON.stringify({ ...cached, baseUrl: "http://elsewhere" }));
        assert.deepEqual(readCatalogCache([], path, now), []);
        writeFileSync(path, JSON.stringify({ ...cached, version: 2 }));
        assert.deepEqual(readCatalogCache([], path, now), []);
        writeFileSync(path, JSON.stringify({ ...cached, catalog: { object: "list", data: [{ id: "incomplete" }] } }));
        assert.deepEqual(readCatalogCache([], path, now), []);
        writeFileSync(path, "not JSON");
        assert.deepEqual(readCatalogCache([], path, now), []);
        writeCatalogCache(catalog, path, now);
        assert.deepEqual(readdirSync(dirname(path)), ["meridian-models.json"]);
        writeCatalogCache(catalog, join(path, "cannot-create-a-directory"), now);
        assert.equal(readCatalogCache([], path, now).length, 1);
      }
    TS
  end

  def test_restart_during_outage_restores_the_last_valid_catalog
    verify_contract(<<~TS)
      import meridian from #{EXTENSION.to_json};
      async function check() {
        const catalog = { object: "list", data: [{ id: "cached", object: "model", owned_by: "anthropic",
          display_name: "Cached", context_window: 200000, capabilities: {} }] };
        globalThis.fetch = async () => new Response(JSON.stringify(catalog));
        let registered;
        const pi = { on() {}, registerProvider: (_id, config) => { registered = config; } };
        await meridian(pi);
        assert.equal(registered.models[0].id, "cached");
        globalThis.fetch = async () => { throw new Error("offline"); };
        let notice;
        console.error = (text) => { notice = text; };
        await meridian(pi);
        assert.equal(registered.models[0].id, "cached");
        assert.match(notice, /Using the cached Meridian catalog/);
        await assert.rejects(registered.refreshModels({ allowNetwork: true, signal: new AbortController().signal }), /offline/);
        assert.equal((await registered.refreshModels({ allowNetwork: false }))[0].id, "cached");
        globalThis.fetch = async () => new Response(JSON.stringify({ object: "list", data: [] }));
        await assert.rejects(registered.refreshModels({ allowNetwork: true, signal: new AbortController().signal }), /malformed/);
        assert.equal((await registered.refreshModels({ allowNetwork: false }))[0].id, "cached");
      }
    TS
  end
end
