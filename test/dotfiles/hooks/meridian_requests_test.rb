require "test_helper"
require_relative "../../support/meridian_extension_helper"

class MeridianRequestsTest < Minitest::Test
  include MeridianExtensionHelper

  def test_request_identity_roles_auxiliary_isolation_and_header_hygiene
    verify_contract(<<~TS)
      import { requestOptions, auxiliaryHeaders, header } from #{"#{HELPERS}/requests.ts".to_json};
      async function check() {
        const context = { messages: [{ role: "system", content: "Normal Pi prompt" }] };
        const options = {
          sessionId: "root", reasoning: "max", signal: new AbortController().signal,
          headers: { "x-meridian-agent": "pi", "X-Session-Affinity": "root", "X-OpenCode-Agent-Mode": "stale", Authorization: "secret" },
          onPayload: () => {}, onResponse: () => {},
        };
        const primary = requestOptions(context, options, { sessionId: "root" });
        assert.equal(primary.headers["x-opencode-agent-mode"], "primary");
        assert.equal(primary.headers["x-opencode-agent-name"], "pi");
        assert.equal(header(primary.headers, "x-session-affinity"), "root");
        assert.equal(primary.headers["X-OpenCode-Agent-Mode"], undefined);
        assert.equal(primary.headers.Authorization, "secret");
        assert.equal(primary.signal, options.signal);
        assert.equal(primary.onPayload, options.onPayload);
        assert.equal(primary.onResponse, options.onResponse);
        assert.equal(primary.reasoning, "max");
        assert.equal(options.headers["X-OpenCode-Agent-Mode"], "stale");
        assert.ok(primary.headers["x-request-id"]);
        const explicit = requestOptions(context, { ...options, headers: { "x-session-affinity": "explicit" } }, { sessionId: "root" });
        assert.equal(header(explicit.headers, "x-session-affinity"), "explicit");
        const child = requestOptions({ messages: [{ role: "system", content: '<active_agent name="reviewer"/>\\nPrompt' }] },
          { ...options, sessionId: "child" }, { sessionId: "root" });
        assert.equal(child.headers["x-opencode-agent-name"], "reviewer");
        assert.equal(child.headers["x-opencode-agent-mode"], "subagent");
        assert.equal(header(child.headers, "x-session-affinity"), "child");
        const unicodeChild = requestOptions({ messages: [{ role: "system", content: '<active_agent name="レビュー"/>' }] },
          { ...options, sessionId: "child" }, { sessionId: "root" });
        assert.equal(unicodeChild.headers["x-opencode-agent-mode"], "subagent");
        assert.doesNotThrow(() => new Headers(unicodeChild.headers));
        const background = requestOptions(context, { ...options, sessionId: "child" }, { sessionId: "child", child: true });
        assert.equal(background.headers["x-opencode-agent-mode"], "subagent");
        for (const compacting of [false, true]) {
          const auxiliary = requestOptions(context, { ...options, sessionId: "auxiliary" }, { sessionId: "root", compacting });
          assert.equal(auxiliary.headers["x-session-affinity"], "auxiliary");
          assert.equal(auxiliary.headers["x-meridian-source"], compacting ? "subagent-compaction" : "subagent-generate");
        }
        const title = auxiliaryHeaders({ ...options.headers, "X-OpenCode-Session": "root", "x-session-id": "root" }, "title", "title-id");
        assert.equal(title["x-session-affinity"], "title-id");
        assert.equal(title["X-OpenCode-Session"], undefined);
        assert.equal(title["x-session-id"], undefined);
        assert.equal(title["x-meridian-source"], "subagent-title");
        assert.deepEqual(auxiliaryHeaders({ "x-meridian-agent": "other" }, "title", "title-id"), { "x-meridian-agent": "other" });
        const generated = requestOptions(context, { headers: { "x-meridian-agent": "pi" } }, {});
        assert.ok(generated.headers["x-session-affinity"]);
        assert.equal(header({ "X-Request-ID": "chosen" }, "x-request-id"), "chosen");
      }
    TS
  end
end
