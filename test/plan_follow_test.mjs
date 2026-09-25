import assert from "node:assert/strict";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import planFollow, { parsePlan } from "../files/home/.pi/agent/extensions/plan_follow.ts";

const example = `# Work\n\n- [x] Inspect\n- [ ] Build <!-- active -->\n- [ ] Deploy <!-- blocked: waiting for credentials -->\n- [ ] Test\n`;

test("classifies unordered checklist work and ignores nested checklist items", () => {
	const result = parsePlan(`${example}  - [ ] nested\n`);
	assert.deepEqual(result.items.map((item) => item.status), ["done", "active", "blocked", "available"]);
	assert.equal(result.error, undefined);
});

test("refuses ambiguous plans instead of guessing", () => {
	assert.match(parsePlan("- [ ] one <!-- active -->\n- [ ] two <!-- active -->").error, /More than one/);
	assert.match(parsePlan("- [x] done <!-- blocked: why -->").error, /completed/);
	assert.match(parsePlan("- [ ] one <!-- blocked: why --> <!-- active -->").error, /both active and blocked/);
	assert.match(parsePlan("- [ ] empty <!-- blocked: -->").error, /status marker/);
	assert.match(parsePlan("- [ ]").error, /no description/);
	assert.match(parsePlan("# prose only").error, /No top-level/);
});

async function harness() {
	const cwd = await mkdtemp(join(tmpdir(), "plan-follow-"));
	const file = join(cwd, "PLAN.md");
	await writeFile(file, example);
	const handlers = new Map();
	const entries = [];
	const sent = [];
	const widgets = [];
	const pi = {
		on(name, fn) { handlers.set(name, fn); },
		registerCommand() {},
		appendEntry(customType, data) { entries.push({ type: "custom", customType, data }); },
		sendUserMessage(message) { sent.push(message); },
	};
	const ctx = {
		cwd, hasUI: true,
		hasPendingMessages: () => false,
		sessionManager: { getBranch: () => entries },
		ui: { setWidget(_key, lines) { widgets.push(lines); }, notify() {} },
	};
	planFollow(pi);
	await handlers.get("session_start")({}, ctx);
	await handlers.get("input")({ source: "interactive", text: "/plan-follow PLAN.md" }, ctx);
	return { cwd, file, handlers, ctx, sent, widgets, entries };
}

async function finishRun(h, stopReason = "stop") {
	await h.handlers.get("agent_start")({}, h.ctx);
	h.handlers.get("agent_end")({ messages: [{ role: "assistant", stopReason }] });
	await h.handlers.get("agent_settled")({}, h.ctx);
}

test("continues useful work, then pauses after repeated no-progress runs", async () => {
	const h = await harness();
	await finishRun(h);
	assert.equal(h.sent.length, 1);
	await finishRun(h);
	assert.equal(h.sent.length, 1);
	assert.match(h.widgets.at(-1)[0], /paused/);
});

test("progress resets the no-progress limit", async () => {
	const h = await harness();
	await finishRun(h);
	await h.handlers.get("agent_start")({}, h.ctx);
	await writeFile(h.file, example.replace("- [ ] Test", "- [x] Test"));
	h.handlers.get("agent_end")({ messages: [{ role: "assistant", stopReason: "stop" }] });
	await h.handlers.get("agent_settled")({}, h.ctx);
	assert.equal(h.sent.length, 2);
});

test("does not continue when all outstanding work is blocked", async () => {
	const h = await harness();
	await writeFile(h.file, "- [x] Inspect\n- [ ] Deploy <!-- blocked: credentials -->\n");
	await finishRun(h);
	assert.equal(h.sent.length, 0);
});

test("an interrupted run does not restart, and human input pauses the plan", async () => {
	const h = await harness();
	await finishRun(h, "aborted");
	assert.equal(h.sent.length, 0);
	await h.handlers.get("input")({ source: "interactive", text: "Let's discuss this" }, h.ctx);
	await finishRun(h);
	assert.equal(h.sent.length, 0);
	assert.match((await readFile(h.file, "utf8")), /Build/);
});

test("restores the selected plan from session entries", async () => {
	const h = await harness();
	h.widgets.length = 0;
	await h.handlers.get("session_start")({}, h.ctx);
	assert.match(h.widgets.at(-1)[0], /PLAN.md/);
});
