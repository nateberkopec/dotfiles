import assert from "node:assert/strict";
import { mock, test } from "node:test";

// Enabled before import so the extension's poll delay and retry interval use fake time.
mock.timers.enable({ apis: ["setTimeout", "setInterval"] });

const { default: extension } = await import("../files/home/.pi/agent/extensions/executor-watch/index.ts");

const handle = ({ app, run }, status) => ({ id: run, app, workflow: "any_workflow", status });

const outcome = (value) => ({
	ok: true,
	result: {
		content: [{ type: "text", text: JSON.stringify({ status: "completed", execution: { ok: true, value } }) }],
	},
});

const requested = (request) => JSON.parse(request.args.code.match(/workflows\.get\((.*)\);$/)[1]).path;

const tick = () => new Promise((resolve) => setImmediate(resolve));

async function advance(ms) {
	await tick();
	mock.timers.tick(ms);
	await tick();
}

function harness(entries = []) {
	const events = new Map();
	const messages = [];
	const requests = [];
	const state = { idle: true, status: "running" };
	let tool;
	const ctx = { isIdle: () => state.idle, sessionManager: { getBranch: () => entries } };

	const h = {
		events,
		entries,
		messages,
		requests,
		state,
		ctx,
		get tool() {
			return tool;
		},
		respond: (request) => Promise.resolve(outcome(handle(requested(request), state.status))),
	};

	extension({
		on: (event, handler) => events.set(event, handler),
		events: {
			emit: (_channel, request) => {
				requests.push(request);
				request.result = h.respond(request);
			},
		},
		registerTool: (value) => {
			tool = value;
		},
		appendEntry: (customType, data) => entries.push({ type: "custom", customType, data }),
		sendMessage: (message, options) => messages.push({ message, options }),
	});
	events.get("session_start")({}, ctx);

	return h;
}

const attach = (h, run = "wfr_1") => h.tool.execute("call", { app: "app_1", run }, undefined, undefined, h.ctx);

const shutdown = (h) => h.events.get("session_shutdown")();

test("attach polls server-1 in the background and wakes an idle session once", async () => {
	const h = harness();
	const result = await attach(h);
	assert.ok(result.content[0].text.includes("Return control"));
	assert.deepEqual(h.entries.at(-1).data.pending, [{ app: "app_1", run: "wfr_1" }]);
	h.state.status = "complete";
	await advance(15000);
	assert.equal(h.messages.length, 1);
	assert.equal(h.messages[0].message.customType, "executor-watch-complete");
	assert.deepEqual(h.messages[0].options, { triggerTurn: true, deliverAs: "followUp" });
	assert.deepEqual(h.entries.at(-1).data.pending, []);
	assert.ok(h.requests.every((request) => request.server === "server-1" && request.tool === "server-1_execute"));
	assert.ok(h.requests.every((request) => request.args.code.includes(".workflows.get(")));
	await advance(15000);
	assert.equal(h.messages.length, 1);
	shutdown(h);
});

test("a terminal run returns its result without attaching", async () => {
	const h = harness();
	h.state.status = "complete";
	const result = await attach(h);
	assert.ok(!result.content[0].text.includes("Return control"));
	await advance(15000);
	assert.equal(h.requests.length, 1);
	assert.equal(h.messages.length, 0);
});

test("completion waits while busy without an agent run, but follows up during one", async () => {
	const h = harness();
	h.state.idle = false;
	await attach(h);
	h.state.status = "complete";
	await advance(15000);
	assert.equal(h.messages.length, 0);
	h.state.idle = true;
	await advance(1000);
	assert.equal(h.messages.length, 1);
	h.state.idle = false;
	h.state.status = "running";
	h.events.get("agent_start")();
	await attach(h, "wfr_2");
	h.state.status = "errored";
	await advance(15000);
	assert.equal(h.messages.length, 2);
	shutdown(h);
});

test("reload reattaches persisted runs automatically without starting replacements", async () => {
	const h = harness([
		{ type: "custom", customType: "executor-watch-state", data: { pending: [{ app: "app_old", run: "wfr_old" }] } },
	]);

	await tick();
	assert.equal(h.requests.length, 1);
	assert.deepEqual(requested(h.requests[0]), { app: "app_old", run: "wfr_old" });
	assert.ok(!h.requests.some((request) => request.args.code.includes("mutations")));
	shutdown(h);
});

test("switching sessions suppresses late completion from the previous owner", async () => {
	const h = harness();
	await attach(h);
	let resolve;
	h.respond = () =>
		new Promise((r) => {
			resolve = r;
		});
	await advance(15000);
	const stale = resolve;
	shutdown(h);
	h.events.get("session_start")({}, h.ctx);
	stale(outcome(handle({ app: "app_1", run: "wfr_1" }, "complete")));
	await tick();
	assert.equal(h.messages.length, 0);
	shutdown(h);
});

test("sustained tracking failure is reported and the run stays pending for reattach", async () => {
	const h = harness();
	await attach(h);
	h.respond = () => Promise.resolve({ ok: false, error: new Error("MCP tool call failed: tool_not_found") });

	for (let i = 0; i < 5; i++) await advance(15000);
	assert.equal(h.messages.length, 1);
	assert.equal(h.messages[0].message.details.status, "tracking_error");
	assert.match(h.messages[0].message.details.error, /tool_not_found/);
	assert.deepEqual(h.entries.at(-1).data.pending, [{ app: "app_1", run: "wfr_1" }]);
	shutdown(h);
});
