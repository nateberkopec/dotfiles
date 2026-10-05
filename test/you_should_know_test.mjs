import assert from "node:assert/strict";
import { test } from "node:test";
import extension from "../files/home/.pi/agent/extensions/you-should-know/index.ts";
import { ObserverUI } from "../files/home/.pi/agent/extensions/you-should-know/ui.ts";
import { JEV_MODEL } from "../files/home/.pi/agent/extensions/you-should-know/jev.ts";

process.env.TYPESAFE_API_KEY = "fixture-not-a-secret";
const decision = (p = 1) => ({ model: JEV_MODEL, usage: { input_tokens: 100 }, answers: {
	interrupt: { type: "choice", choice: p >= 0.5 ? "warn" : "quiet", confidence: 1, probabilities: { warn: p, quiet: 1 - p } },
	category: { type: "choice", choice: "verification", confidence: 1, probabilities: { verification: 1, data_loss: 0, security: 0, none: 0 } },
} });
async function mock(p, run) {
	const prior = globalThis.fetch, calls = [];
	globalThis.fetch = async (url, options) => { calls.push({ url, options }); return new Response(JSON.stringify(decision(p))); };
	try { await run(calls); } finally { globalThis.fetch = prior; }
}
function harness({ response, available = true, mode = "json", signal } = {}) {
	const hooks = new Map(), entries = [], requests = [], notices = [], widgets = [];
	let branch = [], command;
	const result = response || { stopReason: "stop", content: [{ type: "text", text: "Tests failed; do not deploy." }], usage: { input: 20, output: 10, cost: { total: 0.0001 } } };
	const ctx = { mode, signal, sessionManager: { getBranch: () => branch, getEntries: () => entries },
		ui: { setWidget: (...args) => widgets.push(args), notify: (...args) => notices.push(args) },
		modelRegistry: { find: (provider, id) => { assert.equal(provider, "openai"); assert.equal(id, "gpt-6-luna"); return available ? { id, provider } : undefined; },
			streamSimple: (model, context, options) => { requests.push({ model, context, options }); return { result: () => typeof result === "function" ? result(options) : Promise.resolve(result) }; } } };
	extension({ on: (name, fn) => hooks.set(name, fn), registerCommand: (name, spec) => { assert.equal(name, "ysk-demo"); command = spec.handler; },
		appendEntry: (customType, data) => { const entry = { type: "custom", customType, data }; entries.push(entry); branch.push(entry); } });
	return { ctx, entries, requests, notices, widgets, command: (args) => command(args, ctx),
		emit: (name, event = {}) => hooks.get(name)?.(event, ctx),
		message(role, text) { const message = { role, content: [{ type: "text", text }] }; const entry = { type: "message", message }; branch.push(entry); entries.push(entry); return message; },
		branch(next) { branch = next; } };
}
const notes = (h) => h.entries.filter((e) => e.customType === "you-should-know-note");
const usage = (h) => h.entries.filter((e) => e.customType === "you-should-know-usage");
const settle = () => new Promise((resolve) => setImmediate(resolve));

for (const outcome of ["note", "NONE", "failure", "cancel", "off", "quiet"]) test(`provisional UI only after the gate and clears on ${outcome}`, async () => mock(outcome === "quiet" ? 0 : 1, async () => {
	const original = ObserverUI.prototype.note, updates = [], done = Promise.withResolvers(), main = new AbortController();
	ObserverUI.prototype.note = async function (text, current, explaining = false) {
		if (current()) updates.push({ text, explaining });
		return original.call(this, text, current, explaining);
	};
	const h = harness({ signal: main.signal, response: () => done.promise });
	try {
		h.message("assistant", "Check this claim"); const final = h.emit("agent_end"); await settle();
		if (outcome === "quiet") { await final; assert.equal(updates.some((u) => u.explaining), false); return; }
		assert.deepEqual(updates.at(-1), { text: "Reviewing a possible issue", explaining: true });
		assert.equal(notes(h).length, 0, "provisional state is never persisted as a warning");
		if (outcome === "cancel") main.abort();
		else if (outcome === "off") await h.command("off");
		else done.resolve({ stopReason: outcome === "failure" ? "error" : "stop", content: [{ type: "text", text: outcome === "note" ? "Verify the backup." : "NONE" }] });
		await final;
		assert.deepEqual(updates.at(-1), { text: outcome === "note" ? "Verify the backup." : "", explaining: false });
		done.resolve({ stopReason: "stop", content: [{ type: "text", text: "STALE" }] }); await settle();
		assert.notEqual(updates.at(-1).text, "STALE");
	} finally { await h.emit("session_shutdown"); ObserverUI.prototype.note = original; }
}));

test("default-on real observer batches Jev and independently calls pinned tool-less Luna", async () => {
	await mock(1, async (calls) => {
		const h = harness(); await h.emit("session_start"); h.message("toolResult", "FAILED duplicate-charge test"); h.message("assistant", "All tests passed; deploy.");
		await h.emit("agent_end"); assert.equal(calls.length, 1); assert.equal(h.requests.length, 1);
		const body = JSON.parse(calls[0].options.body); assert.equal(Object.keys(body.questions).length, 2); assert.match(body.state, /FAILED/);
		assert.equal(h.requests[0].context.tools, undefined); assert.equal(h.requests[0].options.maxRetries, 0);
		assert.equal(h.requests[0].options.reasoning, "low"); assert.equal(h.requests[0].options.maxTokens, 512);
		assert.equal(notes(h).at(-1).data.note, "Tests failed; do not deploy."); assert.equal(usage(h).length, 2);
		await h.emit("agent_end"); assert.equal(calls.length, 1, "unchanged source does not trigger another request");
	});
});
for (const [p, threshold, expected] of [[0.84, 0.85, 0], [0.85, 0.85, 1], [0.99, 1, 0], [0, 0, 1]]) {
	test(`gate ${p} >= ${threshold}: ${Boolean(expected)}`, async () => mock(p, async () => {
		const h = harness(); await h.command(String(threshold)); h.message("assistant", "Check this claim"); await h.emit("agent_end");
		assert.equal(h.requests.length, expected); assert.equal(usage(h).length, expected + 1);
	}));
}
test("off suppresses all requests; commands accept only on/off or finite thresholds", async () => mock(1, async (calls) => {
	const h = harness(); await h.command("off"); h.message("assistant", "Risk"); await h.emit("agent_end"); assert.equal(calls.length, 0);
	for (const value of ["", "status", "dismiss", "1.01", "-0.1", "Infinity", "on extra"]) { await h.command(value); assert.match(h.notices.at(-1)[0], /Usage/); }
	await h.command(".95"); await h.command("on"); await h.emit("agent_end"); assert.equal(calls.length, 1);
}));
test("missing Luna never falls back to main model or even calls Jev", async () => mock(1, async (calls) => {
	const h = harness({ available: false }); h.message("assistant", "Risk"); await h.emit("agent_end");
	assert.equal(calls.length, 0); assert.equal(h.requests.length, 0); assert.match(h.notices[0][0], /openai\/gpt-6-luna/);
}));
test("NONE and below-threshold reviews remove old notes; no fabricated message", async () => {
	const h = harness({ response: { stopReason: "stop", content: [{ type: "text", text: "NONE" }] } });
	await mock(1, async () => { h.message("assistant", "Risk"); await h.emit("agent_end"); assert.equal(notes(h).at(-1).data.note, ""); });
	await mock(0, async () => { h.message("assistant", "Concern acknowledged"); await h.emit("agent_end"); assert.equal(notes(h).at(-1).data.note, ""); });
});
test("message_end includes the unpersisted assistant, and final checkpoint does not duplicate it", async () => mock(1, async (calls) => {
	const h = harness(); h.message("toolResult", "Tests failed"); const message = { role: "assistant", content: [{ type: "text", text: "Tests passed" }] };
	await h.emit("message_end", { message }); await settle(); assert.equal(calls.length, 1);
	assert.match(JSON.parse(calls[0].options.body).state, /Tests passed/);
	h.message("assistant", "Tests passed"); await h.emit("agent_end"); assert.equal(calls.length, 1);
}));
test("intermediate checks throttle; final checkpoint covers later changes", async () => mock(0, async (calls) => {
	const h = harness(); const one = h.message("assistant", "First"); await h.emit("message_end", { message: one }); await settle();
	const two = h.message("assistant", "Second"); await h.emit("message_end", { message: two }); assert.equal(calls.length, 1);
	await h.emit("agent_end"); assert.equal(calls.length, 2); assert.match(JSON.parse(calls[1].options.body).state, /Second/);
}));
test("off aborts in-flight Luna and ignores its late note but counts known spend", async () => mock(1, async () => {
	const done = Promise.withResolvers(); const h = harness({ response: () => done.promise }); h.message("assistant", "Risk");
	await h.emit("message_end", { message: { role: "assistant", content: [] } }); await settle(); await h.command("off");
	assert.equal(h.requests[0].options.signal.aborted, true);
	done.resolve({ stopReason: "stop", content: [{ type: "text", text: "STALE" }], usage: { cost: { total: 0.001 } } }); await settle();
	assert.equal(notes(h).some((e) => e.data.note === "STALE"), false); assert.equal(usage(h).length, 2);
}));
test("active-branch state restores off/threshold, while a new session defaults on", async () => mock(0, async (calls) => {
	const h = harness(); await h.command("off"); await h.command(".9"); await h.emit("session_tree"); h.message("assistant", "Risk");
	await h.emit("agent_end"); assert.equal(calls.length, 0);
	h.branch([]); await h.emit("session_start"); h.message("assistant", "New session"); await h.emit("agent_end");
	assert.equal(calls.length, 1); assert.equal(h.entries.filter((e) => e.customType === "you-should-know-review").at(-1).data.threshold, 0.85);
}));
test("only bounded text is sent; thinking and images stay out; notes strip controls", async () => mock(1, async (calls) => {
	const h = harness({ response: { stopReason: "stop", content: [{ type: "text", text: "\x1b" + "x".repeat(1000) }] } });
	h.message("assistant", "a".repeat(30000)); await h.emit("agent_end");
	assert.ok(JSON.parse(calls[0].options.body).state.length < 24100); assert.equal(notes(h).at(-1).data.note.length, 600);
	assert.equal(notes(h).at(-1).data.note.includes("\x1b"), false);
}));
for (const stage of ["jev", "luna"]) test(`main-run cancellation during ${stage} releases agent_end and prevents another checkpoint`, async () => {
	const prior = globalThis.fetch, main = new AbortController(), done = Promise.withResolvers();
	const calls = [];
	globalThis.fetch = async (url, options) => { calls.push({ url, options }); return stage === "jev" ? done.promise : new Response(JSON.stringify(decision())); };
	const h = harness({ signal: main.signal, response: () => done.promise });
	try {
		h.message("assistant", "Risk"); await h.emit("message_end", { message: { role: "assistant", content: [] } }); await settle();
		const final = h.emit("agent_end"); main.abort();
		assert.equal(stage === "jev" ? calls[0].options.signal.aborted : h.requests[0].options.signal.aborted, true);
		// Pi may clear ctx.signal before agent_end; remember cancellation for this turn.
		h.ctx.signal = undefined; h.message("assistant", "Later changed text"); await final; await h.emit("agent_end");
		assert.equal(calls.length, 1);
		done.resolve(stage === "jev" ? new Response(JSON.stringify(decision())) : { stopReason: "stop", content: [{ type: "text", text: "STALE" }] });
		await settle(); assert.equal(notes(h).some((e) => e.data.note), false);
	} finally { globalThis.fetch = prior; await h.emit("session_shutdown"); }
});
test("already-aborted contexts do not review; a new agent turn can review normally", async () => mock(0, async (calls) => {
	const main = new AbortController(); main.abort(); const h = harness({ signal: main.signal });
	h.message("assistant", "Risk"); await h.emit("agent_end"); assert.equal(calls.length, 0);
	h.ctx.signal = new AbortController().signal; await h.emit("agent_start"); await h.emit("agent_end"); assert.equal(calls.length, 1);
}));
test("main-run signal listener is removed when a review completes", async () => mock(0, async () => {
	const signal = new AbortController().signal; const add = signal.addEventListener.bind(signal), remove = signal.removeEventListener.bind(signal);
	let added = 0, removed = 0;
	signal.addEventListener = (...args) => { added++; return add(...args); };
	signal.removeEventListener = (...args) => { removed++; return remove(...args); };
	const h = harness({ signal }); h.message("assistant", "Quiet"); await h.emit("agent_end");
	assert.equal(added, 1); assert.equal(removed, 1);
}));

test("provider bodies/errors never leak into notices, and unchanged failures do not retry", async () => mock(1, async (calls) => {
	const h = harness({ response: () => Promise.reject(Error("PRIVATE raw provider body")) }); h.message("assistant", "Risk"); await h.emit("agent_end");
	assert.equal(h.notices[0][0].includes("PRIVATE"), false); assert.equal(usage(h).length, 1);
	await h.emit("agent_end"); assert.equal(calls.length, 1);
}));
