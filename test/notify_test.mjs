import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { test } from "node:test";
import "./support/pi_tui_loader.mjs";

const { default: notify } = await import("../files/home/.pi/agent/extensions/notify.ts");

function harness() {
	const handlers = new Map();
	const events = new EventEmitter();

	const state = {
		active: 0,
		idle: true,
		pending: false,
		mode: "tui",
		malformed: false,
		installed: true,
		beforeReply: () => {},
	};

	const ctx = {
		get mode() {
			return state.mode;
		},
		isIdle: () => state.idle,
		hasPendingMessages: () => state.pending,
	};

	events.on("subagents:rpc:v1:request", ({ requestId }) => {
		queueMicrotask(() => {
			state.beforeReply();
			events.emit(
				`subagents:rpc:v1:reply:${requestId}`,
				state.malformed
					? {}
					: {
							version: 1,
							requestId,
							success: true,
							data: { fleet: { version: 1, totalActive: state.active } },
						},
			);
		});
	});
	notify({
		on(name, handler) {
			handlers.set(name, handler);
		},
		getAllTools: () => (state.installed ? [{ name: "subagent" }] : []),
		events: {
			on(name, handler) {
				events.on(name, handler);

				return () => events.off(name, handler);
			},
			emit: (name, data) => events.emit(name, data),
		},
	});
	const dispatch = async (name, payload = {}) => handlers.get(name)?.(payload, ctx);

	const end = async (messages, mode = "tui") => {
		state.mode = mode;
		await dispatch("agent_start");
		await dispatch("agent_end", { messages });
		await dispatch("agent_settled");
	};

	return Object.assign(end, { dispatch, state, events });
}

async function capture(fn) {
	const writes = [];
	const original = process.stdout.write;
	process.stdout.write = (chunk) => {
		writes.push(String(chunk));

		return true;
	};

	try {
		await fn();
	} finally {
		process.stdout.write = original;
	}

	return writes;
}

test("notifies when settled with the last assistant response, not a tool response", async () => {
	const end = harness();

	const writes = await capture(() =>
		end([
			{ role: "assistant", content: "Earlier" },
			{ role: "assistant", content: [{ type: "text", text: "**Done** with [link](https://example.com)" }] },
			{ role: "toolResult", content: "Ignored" },
		]),
	);

	assert.equal(writes.length, 1);
	assert.equal(writes[0], "\x1b]777;notify;π;Done with link\x07");
});

test("does not emit terminal escapes in noninteractive modes", async () => {
	const end = harness();
	assert.deepEqual(await capture(() => end([{ role: "assistant", content: "Done" }], "print")), []);
});

test("falls back for empty responses and sanitizes control characters", async () => {
	const end = harness();
	assert.deepEqual(await capture(() => end([])), ["\x1b]777;notify;Ready for input;\x07"]);
	const [notification] = await capture(() => end([{ role: "assistant", content: "Hi\x1b]777;notify;bad\x07" }]));
	assert.equal(notification.split("\x1b").length - 1, 1);
	assert.equal(notification.split("\x07").length - 1, 1);
});

test("waiting on a debugging subagent is not a request for human input", async () => {
	const h = harness();
	h.state.active = 1;
	assert.deepEqual(
		await capture(() => h([{ role: "assistant", content: "Started the debugging subagent on GPT-6.1 Sol, xhigh." }])),
		[],
	);
	h.state.active = 0;
	h.state.pending = true;
	assert.deepEqual(await capture(() => h.dispatch("agent_settled")), []);
	h.state.pending = false;
	h.state.idle = false;
	assert.deepEqual(await capture(() => h.dispatch("agent_settled")), []);
	h.state.idle = true;
	await h.dispatch("agent_end", {
		messages: [{ role: "assistant", content: "Diagnosis complete. Which fix do you want?" }],
	});
	assert.equal((await capture(() => h.dispatch("agent_settled"))).length, 1);
	assert.deepEqual(await capture(() => h.dispatch("agent_settled")), []);
});

test("agent_end is not the human-ready boundary", async () => {
	const h = harness();
	await h.dispatch("agent_start");
	assert.deepEqual(
		await capture(() =>
			h.dispatch("agent_end", {
				messages: [{ role: "assistant", content: "Waiting on background work" }],
			}),
		),
		[],
	);
});

test("invalid fleet status fails closed", async () => {
	const h = harness();
	h.state.malformed = true;
	assert.deepEqual(await capture(() => h([{ role: "assistant", content: "Done" }])), []);
});

test("invalid active subagent counts fail closed", async () => {
	for (const active of [-1, 0.5, NaN, Infinity, "0", null, undefined]) {
		const h = harness();
		h.state.active = active;
		assert.deepEqual(await capture(() => h([{ role: "assistant", content: "Done" }])), [], `active=${String(active)}`);
	}
});

test("works without pi-subagents installed", async () => {
	const h = harness();
	h.state.installed = false;
	assert.equal((await capture(() => h([{ role: "assistant", content: "Done" }]))).length, 1);
});

test("new work or a session switch during the fleet query invalidates readiness", async () => {
	for (const interrupt of [
		(h) => h.dispatch("agent_start"),
		(h) => h.dispatch("session_tree"),
		(h) => h.events.emit("subagent:async-started"),
		(h) => {
			h.state.pending = true;
		},
	]) {
		const h = harness();
		h.state.beforeReply = () => interrupt(h);
		assert.deepEqual(await capture(() => h([{ role: "assistant", content: "Done" }])), []);
	}
});
