import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { test } from "node:test";
import toksec from "../files/home/.pi/agent/extensions/toksec/index.ts";

function harness(t, { installed = true, branch = [] } = {}) {
	t.mock.timers.enable({ apis: ["Date", "setTimeout"], now: 1000 });
	const handlers = new Map();
	const bus = new EventEmitter();
	let status;
	const ctx = {
		hasUI: true,
		isIdle: () => true,
		hasPendingMessages: () => false,
		sessionManager: { getBranch: () => branch },
		ui: { setStatus: (_key, text) => { status = text; }, theme: { fg: (_color, text) => text } },
	};
	const pi = {
		on(name, handler) { handlers.set(name, [...(handlers.get(name) ?? []), handler]); },
		events: {
			on(name, handler) { bus.on(name, handler); return () => bus.off(name, handler); },
			emit(name, data) { bus.emit(name, data); },
		},
		getAllTools: () => installed ? [{ name: "subagent" }] : [],
		appendEntry(customType, data) { branch.push({ type: "custom", customType, data }); },
	};
	toksec(pi);
	return {
		ctx, bus, branch,
		get status() { return status; },
		async emit(name, event = {}) { for (const handler of handlers.get(name) ?? []) await handler(event, ctx); },
		fleet(totalActive) {
			bus.removeAllListeners("subagents:rpc:v1:request");
			bus.on("subagents:rpc:v1:request", (request) => {
				queueMicrotask(() => bus.emit(`subagents:rpc:v1:reply:${request.requestId}`, {
					version: 1, requestId: request.requestId, success: true,
					data: { fleet: { version: 1, totalActive, entries: [] } },
				}));
			});
		},
	};
}

test("shows TBHT before token samples exist and averages completed human spans", async (t) => {
	const h = harness(t, { installed: false });
	await h.emit("session_start");
	assert.match(h.status, /TBHT --\.-s$/);
	await h.emit("input", { source: "interactive" });
	t.mock.timers.tick(10_000);
	await h.emit("agent_settled");
	assert.match(h.status, /TBHT 10\.0s$/);
	t.mock.timers.tick(100_000); // Human thinking time does not belong to the next span.
	await h.emit("input", { source: "rpc" });
	t.mock.timers.tick(30_000);
	await h.emit("agent_settled");
	assert.match(h.status, /TBHT 20\.0s$/);
	await h.emit("model_select", { model: { provider: "test", id: "other" } });
	assert.match(h.status, /TBHT 20\.0s$/);
});

test("background workflow pauses and completion wakes stay in one span", async (t) => {
	const h = harness(t);
	await h.emit("session_start");
	await h.emit("input", { source: "interactive" });
	h.fleet(2);
	t.mock.timers.tick(10_000);
	await h.emit("agent_settled");
	assert.match(h.status, /TBHT --\.-s$/);
	await h.emit("input", { source: "extension" });
	await h.emit("agent_start");
	h.fleet(1);
	t.mock.timers.tick(20_000);
	await h.emit("agent_settled");
	assert.match(h.status, /TBHT --\.-s$/);
	await h.emit("input", { source: "interactive" }); // Does not reset during background work.
	h.fleet(0);
	t.mock.timers.tick(60_000);
	await h.emit("agent_settled");
	assert.match(h.status, /TBHT 1\.5m$/);
	await h.emit("input", { source: "extension" });
	t.mock.timers.tick(30_000);
	await h.emit("agent_settled");
	assert.match(h.status, /TBHT 1\.5m$/);
});

test("restores completed and in-flight spans on reload and resets on tree navigation", async (t) => {
	const h = harness(t, { installed: false });
	await h.emit("session_start");
	await h.emit("input", { source: "interactive" });
	t.mock.timers.tick(10_000);
	await h.emit("session_shutdown");
	await h.emit("session_start");
	t.mock.timers.tick(10_000);
	await h.emit("agent_settled");
	assert.match(h.status, /TBHT 20\.0s$/);
	await h.emit("session_start");
	assert.match(h.status, /TBHT 20\.0s$/);
	h.branch.length = 0;
	await h.emit("session_tree");
	assert.match(h.status, /TBHT --\.-s$/);
});

test("does not finalize while a new parent run starts during the status request", async (t) => {
	const h = harness(t);
	await h.emit("session_start");
	await h.emit("input", { source: "interactive" });
	h.fleet(0);
	h.bus.on("subagents:rpc:v1:request", () => { void h.emit("agent_start"); });
	t.mock.timers.tick(10_000);
	await h.emit("agent_settled");
	assert.match(h.status, /TBHT --\.-s$/);
	h.fleet(0);
	t.mock.timers.tick(10_000);
	await h.emit("agent_settled");
	assert.match(h.status, /TBHT 20\.0s$/);
});

test("status timeouts surface errors and never count as idle", async (t) => {
	const h = harness(t);
	await h.emit("session_start");
	await h.emit("input", { source: "interactive" });
	const settled = h.emit("agent_settled");
	const rejected = assert.rejects(settled, /status timed out/);
	t.mock.timers.tick(2000);
	await rejected;
	assert.match(h.status, /TBHT --\.-s$/);
	assert.equal(h.bus.eventNames().filter((name) => name.startsWith("subagents:rpc:v1:reply:")).length, 0);
	h.fleet(0);
	t.mock.timers.tick(8000);
	await h.emit("agent_settled");
	assert.match(h.status, /TBHT 10\.0s$/);
});

test("does not measure child sessions", async (t) => {
	const previous = process.env.PI_SUBAGENT_DEPTH;
	process.env.PI_SUBAGENT_DEPTH = "1";
	t.after(() => {
		if (previous === undefined) delete process.env.PI_SUBAGENT_DEPTH;
		else process.env.PI_SUBAGENT_DEPTH = previous;
	});
	const h = harness(t, { installed: false });
	await h.emit("session_start");
	await h.emit("input", { source: "rpc" });
	t.mock.timers.tick(10_000);
	await h.emit("agent_settled");
	assert.match(h.status, /TBHT --\.-s$/);
	assert.equal(h.branch.length, 0);
});
