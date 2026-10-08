import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import net from "node:net";
import { mock, test } from "node:test";
import extension from "../files/home/.pi/agent/extensions/herdr-status/index.ts";

const flush = () => new Promise((resolve) => setImmediate(resolve));

async function harness(t, children = 0) {
	const saved = { ...process.env },
		reports = [],
		handlers = new Map(),
		bus = new EventEmitter();

	Object.assign(process.env, { HERDR_ENV: "1", HERDR_PANE_ID: "w1:p1", HERDR_SOCKET_PATH: "/synthetic/socket" });
	delete process.env.PI_SUBAGENT_CHILD;
	mock.method(net, "createConnection", () => {
		const socket = new EventEmitter();
		socket.destroy = () => {};

		socket.write = (text) => {
			reports.push(JSON.parse(text));
			queueMicrotask(() => socket.emit("data", Buffer.from('{"result":{}}\n')));
		};

		queueMicrotask(() => socket.emit("connect"));

		return socket;
	});

	const fleet = { totalActive: children },
		ctx = { mode: "tui", isIdle: () => true, sessionManager: { getSessionFile: () => "/synthetic/session.jsonl" } };

	extension({
		on: (name, handler) => handlers.set(name, handler),
		getAllTools: () => [{ name: "subagent" }],
		events: {
			on: (name, handler) => {
				bus.on(name, handler);

				return () => bus.off(name, handler);
			},
			emit: (name, data) => bus.emit(name, data),
		},
	});
	bus.on("subagents:rpc:v1:request", (request) =>
		bus.emit(`subagents:rpc:v1:reply:${request.requestId}`, {
			version: 1,
			requestId: request.requestId,
			success: true,
			data: { fleet: { version: 1, ...fleet } },
		}),
	);
	t.after(() => {
		handlers.get("session_shutdown")();
		mock.restoreAll();
		process.env = saved;
	});

	const h = {
		reports,
		handlers,
		bus,
		fleet,
		ctx,
		state: () => reports.at(-1)?.params.state,
		async start() {
			await handlers.get("session_start")({ reason: "startup" }, ctx);
			await flush();
		},
		async emit(kind, active, label) {
			bus.emit(`herdr:${kind}`, { active, label });
			await flush();
		},
	};

	await h.start();

	return h;
}

test("parent and counted children stay working until both settle; identity is preserved", async (t) => {
	const h = await harness(t);
	assert.equal(h.state(), "idle");
	h.handlers.get("agent_start")({}, h.ctx);
	await h.emit("busy", true);
	await h.emit("busy", false);
	assert.equal(h.state(), "working");
	await h.emit("busy", true);
	await h.emit("busy", true);
	await h.emit("busy", false);
	h.fleet.totalActive = 1;
	await h.handlers.get("agent_settled")({}, { ...h.ctx });
	await flush();
	assert.equal(h.state(), "working");
	h.fleet.totalActive = 0;
	await h.emit("busy", false);
	assert.equal(h.state(), "idle");
	assert.equal(h.reports[0].method, "pane.report_agent_session");

	for (const { params } of h.reports)
		assert.deepEqual([params.source, params.agent_session_path], ["herdr:pi", "/synthetic/session.jsonl"]);
});

test("reload restores delegated work and completion", async (t) => {
	const h = await harness(t, 2);
	assert.equal(h.state(), "working");
	h.fleet.totalActive = 0;
	await h.start();
	assert.equal(h.state(), "idle");
});

test("existing blocked overlays override work and return to working", async (t) => {
	const h = await harness(t, 1);
	await h.emit("blocked", true, "Existing overlay");
	assert.equal(h.state(), "blocked");
	await h.emit("blocked", false);
	assert.equal(h.state(), "working");
});

test("busy label replacement never reports false completion", async (t) => {
	const h = await harness(t);
	await h.emit("busy", true, "first task");
	const before = h.reports.length;
	h.bus.emit("herdr:busy", { active: false });
	h.bus.emit("herdr:busy", { active: true, label: "next task" });
	await flush();
	assert.ok(h.reports.length > before);
	assert.ok(h.reports.slice(before).every((report) => report.params.state === "working"));
});

test("headless, non-Herdr and non-TUI sessions do not publish", async (t) => {
	const h = await harness(t);
	h.ctx.mode = "rpc";
	await h.start();
	const before = h.reports.length;
	await h.emit("busy", true);
	assert.equal(h.reports.length, before);

	const pi = new Proxy(
		{},
		{
			get() {
				assert.fail("Must not register child or non-Herdr hooks");
			},
		},
	);

	process.env.PI_SUBAGENT_CHILD = "1";
	extension(pi);
	delete process.env.PI_SUBAGENT_CHILD;
	process.env.HERDR_ENV = "0";
	extension(pi);
});
