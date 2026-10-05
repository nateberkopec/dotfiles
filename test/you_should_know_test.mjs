import assert from "node:assert/strict";
import { test } from "node:test";
import extension from "../files/home/.pi/agent/extensions/you-should-know.ts";

function harness({ mode = "tui", result, branch = [], observerAvailable = true } = {}) {
	const hooks = new Map(), entries = [], widgets = [], notices = [], requests = [];
	let command;
	const response = result || { stopReason: "stop", content: [{ type: "text", text: "The backup has not been verified." }], usage: { totalTokens: 10 } };
	const ctx = {
		mode, model: { id: "test-model" },
		sessionManager: { getBranch: () => branch },
		ui: { setWidget: (...args) => widgets.push(args), notify: (...args) => notices.push(args) },
		modelRegistry: { find(provider, id) {
			assert.equal(provider, "openai"); assert.equal(id, "gpt-6-luna");
			return observerAvailable ? { provider, id } : undefined;
		}, streamSimple(model, context, options) {
			requests.push({ model, context, options });
			return { result: () => typeof response === "function" ? response(options) : Promise.resolve(response) };
		} },
	};
	extension({ on: (name, handler) => hooks.set(name, handler), registerCommand: (_name, spec) => { command = spec.handler; },
		appendEntry: (customType, data) => { const entry = { type: "custom", customType, data }; entries.push(entry); branch.push(entry); } });
	const emit = async (name, event = {}) => hooks.get(name)?.(event, ctx);
	const assistant = (text) => branch.push({ type: "message", message: { role: "assistant", content: [{ type: "text", text }] } });
	return { ctx, entries, widgets, notices, requests, emit, assistant, command: (args) => command(args, ctx) };
}

test("off by default, opt-in observer has no tools and never injects model context", async () => {
	const h = harness(); h.assistant("Delete the database before checking the backup.");
	await h.emit("agent_end"); assert.equal(h.requests.length, 0);
	await h.command("on"); await h.emit("agent_end");
	assert.equal(h.requests.length, 1);
	assert.deepEqual(h.requests[0].model, { provider: "openai", id: "gpt-6-luna" });
	assert.equal(h.entries.find((e) => e.customType.endsWith("-review")).data.model, "gpt-6-luna");
	assert.equal(h.requests[0].context.tools, undefined);
	assert.match(h.requests[0].context.systemPrompt, /untrusted data/);
	assert.deepEqual(h.widgets.at(-1)[1], ["You should know: The backup has not been verified."]);
	assert.equal(h.entries.filter((e) => e.customType.endsWith("-review")).length, 1);
	await h.emit("agent_end"); assert.equal(h.requests.length, 1);
});

test("missing pinned observer warns without falling back to the main model", async () => {
	const h = harness({ observerAvailable: false });
	await h.command("on"); h.assistant("Risky change"); await h.emit("agent_end");
	assert.equal(h.requests.length, 0);
	assert.match(h.notices.at(-1)[0], /openai\/gpt-6-luna is unavailable/);
});

test("pinned observer does not require a main session model", async () => {
	const h = harness(); h.ctx.model = undefined;
	await h.command("on"); h.assistant("Risky change"); await h.emit("agent_end");
	assert.equal(h.requests.length, 1);
	assert.equal(h.requests[0].model.id, "gpt-6-luna");
});

test("NONE is quiet and headless mode stores notes without widgets", async () => {
	const quiet = harness({ result: { stopReason: "stop", content: [{ type: "text", text: "NONE" }] } });
	await quiet.command("on"); quiet.assistant("All checks passed."); await quiet.emit("agent_end");
	assert.equal(quiet.entries.some((e) => e.customType.endsWith("-note")), false);
	const h = harness({ mode: "json" }); await h.command("on"); h.assistant("Risky change"); await h.emit("agent_end");
	assert.equal(h.widgets.length, 0); assert.equal(h.entries.at(-1).customType, "you-should-know-note");
});

test("restores enabled state and notes from the active branch; dismiss and off clear UI", async () => {
	const h = harness({ branch: [
		{ type: "custom", customType: "you-should-know", data: { enabled: true } },
		{ type: "custom", customType: "you-should-know-note", data: { note: "Watch the backup" } },
	] });
	await h.emit("session_start"); assert.match(h.widgets.at(-1)[1][0], /Watch the backup/);
	await h.command("dismiss"); assert.equal(h.widgets.at(-1)[1], undefined);
	await h.command("off"); h.assistant("Risk"); await h.emit("agent_end"); assert.equal(h.requests.length, 0);
	await h.emit("session_tree"); await h.command("status"); assert.match(h.notices.at(-1)[0], /off/);
});

test("background review does not block message_end; off discards stale completion", async () => {
	let finish;
	const h = harness({ result: () => new Promise((resolve) => { finish = resolve; }) });
	await h.command("on"); h.assistant("Risk"); await h.emit("message_end", { message: { role: "assistant", content: [] } });
	assert.equal(h.requests.length, 1); await h.command("off");
	assert.equal(h.requests[0].options.signal.aborted, true);
	finish({ stopReason: "stop", content: [{ type: "text", text: "Stale note" }] });
	await new Promise((resolve) => setImmediate(resolve));
	assert.equal(h.entries.some((e) => e.customType.endsWith("-note")), false);
	await h.emit("session_shutdown");
});

test("coalesces intermediate messages and reviews the final transcript", async () => {
	const h = harness(); await h.command("on"); h.assistant("First");
	await h.emit("message_end", { message: { role: "assistant", content: [] } });
	await new Promise((resolve) => setImmediate(resolve));
	h.assistant("Second"); await h.emit("message_end", { message: { role: "assistant", content: [] } });
	assert.equal(h.requests.length, 1); await h.emit("agent_end"); assert.equal(h.requests.length, 2);
	assert.match(h.requests[1].context.messages[0].content, /Second/);
	assert.equal(h.entries.filter((e) => e.customType.endsWith("-note")).length, 1);
});

test("bounds transcript and note, excludes thinking, strips terminal controls and reports provider errors", async () => {
	const h = harness({ result: { stopReason: "stop", content: [{ type: "text", text: "\u001b" + "x".repeat(1000) }] } });
	await h.command("on"); h.assistant("a".repeat(30_000)); await h.emit("agent_end");
	assert.ok(h.requests[0].context.messages[0].content.length < 24_100);
	assert.equal(h.entries.at(-1).data.note.length, 600);
	assert.equal(h.entries.at(-1).data.note.includes("\u001b"), false);
	const bad = harness({ result: { stopReason: "error", errorMessage: "No credentials", content: [] } });
	await bad.command("on"); bad.assistant("Risk"); await bad.emit("agent_end");
	assert.match(bad.notices.at(-1)[0], /No credentials/);
	assert.equal(bad.entries.some((e) => e.customType.endsWith("-note")), false);
});
