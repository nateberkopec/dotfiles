import assert from "node:assert/strict";
import { test } from "node:test";
import { request as httpRequest } from "node:http";
import { parseSession, branchOf, snapshot, checkpoints, recordedWarnings } from "../tools/ysk-backtest/session.mjs";
import { replay } from "../tools/ysk-backtest/replay.mjs";
import { startServer } from "../tools/ysk-backtest/server.mjs";

const header = { type: "session", version: 3, id: "fixture", cwd: "/test" };

const message = (id, parentId, role, text, seconds = 0, stopReason = "stop") => ({
	type: "message",
	id,
	parentId,
	timestamp: new Date(1700000000000 + seconds * 1000).toISOString(),
	message: { role, stopReason, content: [{ type: "text", text }] },
});

const textOf = (rows) => [header, ...rows].map((row) => JSON.stringify(row)).join("\n");

const rows = [
	message("u", null, "user", "Check evidence"),
	message("a", "u", "assistant", "First claim", 1, "toolUse"),
	message("t", "a", "toolResult", "FAILED", 5),
	message("b", "t", "assistant", "Second claim", 10, "toolUse"),
	message("c", "b", "assistant", "Final claim", 12),
	message("f", "u", "assistant", "Other branch", 50),
];

const decision = { choice: "warn", probability: 0.99, confidence: 0.98, category: "wrong_result" };

test("historical checkpoints follow the selected branch, throttle intermediate turns, and exclude future text", () => {
	const session = parseSession(textOf(rows));
	assert.deepEqual(
		branchOf(session).map((entry) => entry.id),
		["u", "f"],
	);
	const points = checkpoints(session, "c");
	assert.deepEqual(
		points.map((point) => point.id),
		["a", "c"],
	);
	assert.doesNotMatch(points[0].source, /FAILED|Second claim|Final claim|Other branch/);
	assert.match(points[1].source, /toolResult: FAILED/);
	assert.doesNotMatch(points[1].source, /Other branch/);
	assert.equal(snapshot([message("big", null, "assistant", "x".repeat(30000))]).length, 24000);
	assert.equal(
		snapshot([
			{
				type: "message",
				message: {
					role: "assistant",
					content: [
						{ type: "thinking", thinking: "PRIVATE" },
						{ type: "image", data: "PRIVATE" },
					],
				},
			},
		]),
		"",
	);
});

test("malformed sessions fail clearly; legacy linear sessions work without mutation of the source file", () => {
	for (const value of ["", "{}", textOf([rows[0], rows[0]]), textOf([message("a", "missing", "assistant", "X")])])
		assert.throws(() => parseSession(value));
	assert.throws(() => parseSession(`${JSON.stringify(header)}\n{broken`), /line 2/);

	const legacy = parseSession(
		JSON.stringify({ type: "session", version: 1 }) +
			'\n{"type":"message","message":{"role":"assistant","content":"Old"}}',
	);

	assert.equal(checkpoints(legacy)[0].source, "assistant: Old");
	assert.throws(() => branchOf(legacy, "nope"), /Unknown leaf/);
});

test("recorded warnings use saved snapshots and scores, omit clear entries, and dedupe command redisplays", () => {
	const note = {
		type: "custom",
		id: "n",
		parentId: "a",
		customType: "you-should-know-note",
		data: { note: "Warning", id: "issue", source: "original snapshot", decision },
	};

	const session = parseSession(
		textOf([
			rows[0],
			rows[1],
			note,
			{ ...note, id: "n2", parentId: "n" },
			{ ...note, id: "clear", parentId: "n2", data: { note: "" } },
		]),
	);

	const warnings = recordedWarnings(session);
	assert.equal(warnings.length, 1);
	assert.equal(warnings[0].source, "original snapshot");
	assert.equal(warnings[0].exactSnapshot, true);
	assert.equal(warnings[0].decision.confidence, 0.98);
});

test("sequential replay builds only its own offer history and suppresses normalized repeats", async () => {
	const points = checkpoints(parseSession(textOf(rows)), "c"),
		state = {},
		seen = [];

	await replay(points, 0.85, state, new AbortController().signal, async (_ctx, source, history, threshold) => {
		seen.push({ source, offered: [...history.offered], known: [...history.understood], threshold });

		return { decision, note: seen.length === 1 ? "Bad result." : "BAD RESULT!" };
	});
	assert.equal(state.status, "done");
	assert.equal(state.completed, 2);
	assert.equal(state.warnings.length, 1);
	assert.deepEqual(seen[0].offered, []);
	assert.deepEqual(seen[1].offered, ["Bad result."]);
	assert.deepEqual(seen[1].known, []);
});

test("replay errors stop without retries, and cancellation releases a hung observer", async () => {
	const points = checkpoints(parseSession(textOf(rows)), "c"),
		state = {},
		controller = new AbortController();

	let calls = 0;
	await replay(points, 0.85, state, controller.signal, async () => {
		calls++;
		throw Error("Jev HTTP 429");
	});
	assert.equal(state.status, "error");
	assert.equal(calls, 1);
	assert.equal(state.completed, 0);
	const running = replay(points, 0.85, state, controller.signal, async () => new Promise(() => {}));
	controller.abort();
	await running;
	assert.equal(state.status, "stopped");
});

test("loopback server is view-only, requires its token, checks origins, and runs only on explicit POST", async () => {
	let calls = 0;

	const app = await startServer({
		text: textOf(rows),
		name: "fixture.jsonl",
		leaf: "c",
		context: async () => ({}),
		evaluate: async () => {
			calls++;

			return { decision, note: `Warning ${calls}` };
		},
	});

	const root = new URL(app.url),
		token = root.searchParams.get("token"),
		base = root.origin;

	const api = async (route, body) =>
		fetch(`${base}/api/${route}`, {
			method: body === undefined ? "GET" : "POST",
			headers: { "x-review-token": token, "Content-Type": "application/json" },
			body: body === undefined ? undefined : JSON.stringify(body),
		});

	try {
		assert.equal((await fetch(`${base}/api/state`)).status, 403);
		assert.equal(
			(
				await fetch(`${base}/api/replay`, {
					method: "POST",
					headers: { "x-review-token": token, Origin: "https://evil.example" },
					body: "{}",
				})
			).status,
			403,
		);

		const foreignHost = await new Promise((resolve, reject) => {
			const request = httpRequest(
				`${base}/api/state`,
				{ headers: { "x-review-token": token, Host: "evil.example" } },
				(response) => {
					response.resume();
					resolve(response.statusCode);
				},
			);

			request.on("error", reject);
			request.end();
		});

		assert.equal(foreignHost, 403);
		assert.equal((await api("state")).status, 200);
		assert.equal(calls, 0);
		assert.equal((await api("replay", { threshold: 2 })).status, 400);
		assert.equal(calls, 0);
		assert.equal((await api("replay", { threshold: 0.85 })).status, 202);
		let state;

		for (let i = 0; i < 30; i++) {
			state = await (await api("state")).json();

			if (state.status === "done") break;
			await new Promise((resolve) => setTimeout(resolve, 10));
		}

		assert.equal(state.status, "done");
		assert.equal(state.warnings.length, 2);
		assert.equal(calls, 2);
		assert.equal((await api("rating", { good: true })).status, 404);
		assert.equal((await api("session", { text: "invalid" })).status, 400);
		assert.equal((await (await api("state")).json()).session.name, "fixture.jsonl");
		assert.equal((await api("session", { text: textOf([rows[0]]), name: "Empty" })).status, 200);
		assert.equal((await (await api("state")).json()).warnings.length, 0);
	} finally {
		await app.close();
	}
});
