import assert from "node:assert/strict";
import { test } from "node:test";
import { SideChat } from "../files/home/.pi/agent/extensions/btw/thread.ts";

const settle = () => new Promise((resolve) => setImmediate(resolve));

const answer = (question) => {
	const message = {
		role: "assistant",
		content: [{ type: "text", text: "Answer" }],
		stopReason: "stop",
		timestamp: 0,
		api: "openai-responses",
		provider: "openai",
		model: "gpt-6-luna",
		usage: {
			input: 0,
			output: 0,
			cacheRead: 0,
			cacheWrite: 0,
			totalTokens: 0,
			cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
		},
	};

	return { message, messages: [{ role: "user", content: question, timestamp: 0 }, message] };
};

function harness(create) {
	const entries = [],
		sent = [],
		notices = [];

	const ctx = {
		mode: "json",
		cwd: "/tmp",
		isIdle: () => true,
		sessionManager: { getBranch: () => entries },
		ui: { notify: (...args) => notices.push(args) },
	};

	const pi = {
		appendEntry: (customType, data) => entries.push({ type: "custom", customType, data }),
		sendUserMessage: (...args) => sent.push(args),
	};

	return { ctx, entries, sent, notices, chat: new SideChat(pi, "ysk", create) };
}

const spec = {
	id: "issue",
	title: "YSK · Luna",
	model: { provider: "openai", id: "gpt-6-luna" },
	seed: [{ role: "user", content: "Original snapshot", timestamp: 0 }],
	tools: [],
	strict: true,
	opening: "Warning",
};

test("opening without a question makes no request; only explicit handoff reaches main context", async () => {
	let calls = 0;

	const h = harness(async () => {
		calls++;

		return { run: async (q) => answer(q), close() {} };
	});

	await h.chat.open(h.ctx, spec, "");
	assert.equal(calls, 0);
	await h.chat.open(h.ctx, spec, "Explain");
	assert.equal(calls, 1);
	assert.equal(h.sent.length, 0);
	h.chat.inject(h.ctx);
	assert.equal(h.sent.length, 1);
	assert.match(h.sent[0][0], /Explain/);
});

test("close releases a waiting request and ignores a late answer", async () => {
	const done = Promise.withResolvers();
	let closed = 0;
	const h = harness(async () => ({ run: () => done.promise, close: () => closed++ }));
	const request = h.chat.open(h.ctx, spec, "Explain");
	await settle();
	h.chat.close();
	await request;
	assert.ok(closed > 0);
	assert.equal(h.entries.length, 0);
	done.resolve(answer("STALE"));
	await settle();
	assert.equal(h.entries.length, 0);
});

test("branch/session restoration invalidates pending creation and a new request recovers", async () => {
	const creation = Promise.withResolvers();

	let closed = 0,
		ran = 0,
		calls = 0;

	const h = harness(async () => (++calls === 1 ? creation.promise : { run: async (q) => answer(q), close() {} }));
	const request = h.chat.open(h.ctx, spec, "Old");
	await settle();
	h.chat.restore(h.ctx);
	creation.resolve({
		run: async (q) => {
			ran++;

			return answer(q);
		},
		close: () => closed++,
	});
	await request;
	assert.equal(ran, 0);
	assert.equal(closed, 1);
	await h.chat.open(h.ctx, spec, "New");
	assert.equal(h.entries.length, 1);
});

test("new issue excludes earlier issue history; restored current history is bounded to eight turns", async () => {
	const seeds = [];

	const h = harness(async (_ctx, settings) => {
		seeds.push(settings.seed);

		return { run: async (q) => answer(q), close() {} };
	});

	for (let i = 0; i < 10; i++) await h.chat.open(h.ctx, spec, `Question ${i}`);
	h.chat.restore(h.ctx);
	await h.chat.open(h.ctx, spec, "Continued");
	assert.equal(seeds.at(-1).length, 17);
	assert.equal(seeds.at(-1)[1].content, "Question 2");
	await h.chat.open(h.ctx, { ...spec, id: "new-issue" }, "Different");
	assert.equal(seeds.at(-1).length, 1);
});

test("deadline releases an unresponsive request and does not strand busy state", async (t) => {
	t.mock.timers.enable({ apis: ["setTimeout"] });
	const done = Promise.withResolvers();
	let calls = 0;

	const h = harness(async () => ({
		run: (q) => (++calls === 1 ? done.promise : Promise.resolve(answer(q))),
		close() {},
	}));

	const request = h.chat.open(h.ctx, spec, "Stuck");
	await settle();
	t.mock.timers.tick(40_000);
	await request;
	await h.chat.open(h.ctx, spec, "Recovered");
	assert.equal(h.entries.length, 1);
	done.resolve(answer("STALE"));
	await settle();
	assert.equal(h.entries.length, 1);
});
