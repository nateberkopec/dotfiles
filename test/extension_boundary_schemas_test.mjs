import assert from "node:assert/strict";
import { test } from "node:test";
import { Value } from "typebox/value";
import { ChatMessage } from "../files/home/.pi/agent/extensions/shared/chat_message.ts";
import { FleetStatusReply } from "../files/home/.pi/agent/extensions/shared/subagent_status.ts";
import { RequestPayload } from "../files/home/.pi/agent/extensions/datasafe/payload.ts";

test("chat replay preserves SDK system sections and tool declarations", () => {
	const message = {
		role: "system",
		content: "",
		timestamp: 0,
		sections: { preamble: "Instructions", removed: null },
		toolsAdded: [
			{
				name: "read",
				description: "Read a file",
				parameters: { type: "object", properties: { path: { type: "string" } } },
			},
		],
		toolsRemoved: [{ name: "write" }],
	};

	assert.equal(Value.Check(ChatMessage, message), true);
	assert.equal(Value.Check(ChatMessage, { ...message, sections: { preamble: 42 } }), false);
	assert.equal(Value.Check(ChatMessage, { ...message, toolsAdded: [{ name: "read", parameters: {} }] }), false);
});

test("chat replay rejects incomplete assistant messages and invalid tool arguments", () => {
	assert.equal(Value.Check(ChatMessage, { role: "assistant", content: [] }), false);
	const tool = { role: "toolResult", toolCallId: "call", toolName: "read", content: [], isError: false, timestamp: 0 };
	assert.equal(Value.Check(ChatMessage, tool), true);
	assert.equal(Value.Check(ChatMessage, { ...tool, isError: "false" }), false);
});

test("fleet status requires the complete success envelope and a safe active count", () => {
	const reply = (count) => ({
		version: 1,
		requestId: "request",
		success: true,
		data: { fleet: { version: 1, totalActive: count } },
	});

	assert.equal(Value.Check(FleetStatusReply, reply(0)), true);

	for (const count of [-1, 0.5, Number.MAX_SAFE_INTEGER + 1, Infinity, "0"]) {
		assert.equal(Value.Check(FleetStatusReply, reply(count)), false);
	}

	assert.equal(Value.Check(FleetStatusReply, { ...reply(0), success: false }), false);
});

test("provider payloads retain JSON options but reject malformed routing controls", () => {
	assert.equal(
		Value.Check(RequestPayload, {
			model: "model",
			provider: { order: ["provider"], allow_fallbacks: false },
			providerOptions: { gateway: { inferenceRegion: "usa" } },
		}),
		true,
	);

	for (const payload of [
		{ model: [] },
		{ provider: [] },
		{ providerOptions: { gateway: "usa" } },
		{ provider: { callback() {} } },
	]) {
		assert.equal(Value.Check(RequestPayload, payload), false);
	}
});
