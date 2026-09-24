import assert from "node:assert/strict";
import { test } from "node:test";
import compactAt, { parseCap } from "../files/home/.pi/agent/extensions/compact_at.ts";

const MILLION = { provider: "meridian", id: "claude-opus-5", contextWindow: 1_000_000, maxTokens: 128_000 };
const CODEX = { provider: "openai-codex", id: "gpt-6-astra", contextWindow: 272_000, maxTokens: 128_000 };

function harness({ registry = MILLION, branch = [] } = {}) {
	const handlers = new Map();
	const commands = new Map();
	const notices = [];
	let thinkingLevel = "xhigh";
	const ctx = {
		hasUI: true,
		model: registry,
		modelRegistry: { find: (provider, id) => (provider === registry.provider && id === registry.id ? registry : undefined) },
		sessionManager: { getBranch: () => branch },
		ui: { notify: (message, level) => notices.push({ message, level }) },
	};
	const pi = {
		on(name, handler) { handlers.set(name, [...(handlers.get(name) ?? []), handler]); },
		registerCommand(name, options) { commands.set(name, options); },
		appendEntry(customType, data) { branch.push({ type: "custom", customType, data }); },
		getThinkingLevel: () => thinkingLevel,
		setThinkingLevel: (level) => { thinkingLevel = level; },
		async setModel(model) {
			ctx.model = model;
			thinkingLevel = "low";
			return true;
		},
	};
	compactAt(pi);
	return {
		ctx, branch, notices,
		get thinkingLevel() { return thinkingLevel; },
		async emit(name, event = {}) { for (const handler of handlers.get(name) ?? []) await handler(event, ctx); },
		async command(args) { await commands.get("compact-at").handler(args, ctx); },
	};
}

test("clamps a million-token model to 400k and keeps the thinking level", async () => {
	const h = harness();
	await h.emit("session_start");
	assert.equal(h.ctx.model.contextWindow, 400_000);
	assert.equal(h.ctx.model.id, "claude-opus-5");
	assert.equal(h.ctx.model.maxTokens, 128_000);
	assert.equal(h.thinkingLevel, "xhigh");
});

test("leaves models at or below the cap untouched", async () => {
	const h = harness({ registry: CODEX });
	await h.emit("session_start");
	await h.emit("model_select", { model: CODEX });
	await h.emit("turn_start");
	assert.equal(h.ctx.model, CODEX);
});

test("re-applies the clamp after a registry refresh replaces the session model", async () => {
	const h = harness();
	await h.emit("session_start");
	h.ctx.model = MILLION;
	await h.emit("turn_start");
	assert.equal(h.ctx.model.contextWindow, 400_000);
});

test("session override raises the cap, persists it, and never exceeds the real window", async () => {
	const h = harness();
	await h.emit("session_start");
	await h.command("600k");
	assert.equal(h.ctx.model.contextWindow, 600_000);
	assert.deepEqual(h.branch.at(-1), { type: "custom", customType: "compact-at", data: { cap: 600_000 } });
	assert.match(h.notices.at(-1).message, /600k/);
	await h.command("2m");
	assert.equal(h.ctx.model.contextWindow, 1_000_000);
	await h.command("off");
	assert.equal(h.ctx.model.contextWindow, 1_000_000);
	assert.deepEqual(h.branch.at(-1).data, { cap: null });
	await h.command("300000");
	assert.equal(h.ctx.model.contextWindow, 300_000);
});

test("restores the session override on resume", async () => {
	const h = harness({ branch: [{ type: "custom", customType: "compact-at", data: { cap: 700_000 } }] });
	await h.emit("session_start");
	assert.equal(h.ctx.model.contextWindow, 700_000);
	await h.command("");
	assert.match(h.notices.at(-1).message, /700k/);
});

test("rejects bad input without changing the cap", async () => {
	const h = harness();
	await h.emit("session_start");
	await h.command("lots");
	assert.equal(h.notices.at(-1).level, "error");
	assert.equal(h.ctx.model.contextWindow, 400_000);
	assert.equal(h.branch.length, 0);
});

test("parseCap accepts plain numbers, k/m suffixes, and off", () => {
	assert.equal(parseCap("400000"), 400_000);
	assert.equal(parseCap(" 1.5M "), 1_500_000);
	assert.equal(parseCap("250k"), 250_000);
	assert.equal(parseCap("off"), null);
	assert.equal(parseCap("0"), undefined);
	assert.equal(parseCap("-5"), undefined);
	assert.equal(parseCap("k"), undefined);
});
