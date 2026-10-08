require "test_helper"
require_relative "../../support/meridian_extension_helper"

class MeridianWireTest < Minitest::Test
  include MeridianExtensionHelper

  def test_builtin_anthropic_stream_preserves_thinking_tools_usage_and_request_hooks
    verify_contract(<<~TS)
      import meridian from #{EXTENSION.to_json};
      async function check() {
        const catalog = { object: "list", data: [{ id: "claude-new", object: "model", owned_by: "anthropic",
          display_name: "New", context_window: 200000, capabilities: {
            thinking: { supported: true, types: { adaptive: { supported: true } } },
            effort: { high: { supported: true }, max: { supported: true } },
          } }] };
        const requests = [];
        globalThis.fetch = async (url, init) => {
          if (String(url).endsWith("/v1/models")) return new Response(JSON.stringify(catalog));
          requests.push({ headers: new Headers(init.headers), body: JSON.parse(init.body) });
          const events = [
            { type: "message_start", message: { id: "msg-test", type: "message", role: "assistant", model: "claude-new", content: [], stop_reason: null,
              usage: { input_tokens: 2, output_tokens: 0, cache_read_input_tokens: 100, cache_creation_input_tokens: 10 } } },
            { type: "content_block_start", index: 0, content_block: { type: "thinking", thinking: "", signature: "" } },
            { type: "content_block_delta", index: 0, delta: { type: "thinking_delta", thinking: "Thinking" } },
            { type: "content_block_delta", index: 0, delta: { type: "signature_delta", signature: "signed" } },
            { type: "content_block_stop", index: 0 },
            { type: "content_block_start", index: 1, content_block: { type: "tool_use", id: "tool-test", name: "read", input: {} } },
            { type: "content_block_delta", index: 1, delta: { type: "input_json_delta", partial_json: '{"path":"test"}' } },
            { type: "content_block_stop", index: 1 },
            { type: "message_delta", delta: { stop_reason: "tool_use" }, usage: { output_tokens: 8 } },
            { type: "message_stop" },
          ];
          return new Response(events.map(event => `event: ${event.type}\\ndata: ${JSON.stringify(event)}\\n\\n`).join(""), {
            headers: { "content-type": "text/event-stream" },
          });
        };
        const handlers = new Map();
        let config;
        await meridian({ on: (event, handler) => handlers.set(event, handler), registerProvider: (_id, value) => { config = value; } });
        const ctx = { sessionManager: { getSessionId: () => "root" } };
        handlers.get("session_start")({}, ctx);
        const model = { ...config.models[0], provider: "meridian" };
        const context = { messages: [{ role: "system", content: "Test", tools: [{ name: "read", description: "Read", parameters: { type: "object" } }] },
          { role: "user", content: [{ type: "text", text: "hello" }], timestamp: 1 }] };
        let payloads = 0, responses = 0;
        const options = { apiKey: "x", reasoning: "max", sessionId: "root",
          headers: { ...config.headers, "x-opencode-task-budget": "50000", "x-meridian-profile": "work" },
          maxRetries: 0, onPayload: () => { payloads++; }, onResponse: () => { responses++; } };
        const response = await config.streamSimple(model, context, options).result();
        assert.equal(response.stopReason, "toolUse", response.errorMessage);
        assert.equal(response.content[0].thinking, "Thinking");
        assert.equal(response.content[1].name, "read");
        assert.equal(response.usage.cacheRead, 100);
        assert.equal(response.usage.cacheWrite, 10);
        assert.equal(payloads, 1); assert.equal(responses, 1);
        assert.equal(requests[0].body.thinking.type, "adaptive");
        assert.equal(requests[0].body.output_config.effort, "max");
        assert.equal(requests[0].headers.get("x-session-affinity"), "root");
        assert.equal(requests[0].headers.get("x-opencode-agent-mode"), "primary");
        assert.equal(requests[0].headers.get("x-opencode-task-budget"), "50000");
        assert.equal(requests[0].headers.get("x-meridian-profile"), "work");
        handlers.get("session_before_compact")({}, ctx);
        await config.streamSimple(model, context, { ...options, sessionId: "summary" }).result();
        assert.equal(requests[1].headers.get("x-meridian-source"), "subagent-compaction");
        assert.equal(requests[1].headers.get("x-session-affinity"), "summary");
        handlers.get("session_compact_failed")({}, ctx);
        await config.streamSimple(model, context, options).result();
        assert.equal(requests[2].headers.get("x-opencode-agent-mode"), "primary");
      }
    TS
  end
end
