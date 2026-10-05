import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import { WarningInbox } from "../files/home/.pi/agent/extensions/you-should-know/inbox.ts";

const root = fileURLToPath(new URL("../", import.meta.url));
function fixture(run) {
	const dir = mkdtempSync(path.join(tmpdir(), "btw-sessions-")), file = path.join(dir, "session.jsonl");
	const prompt = (...prompts) => {
		execFileSync("pi", ["--offline", "--mode", "json", "--no-extensions", "--no-context-files", "--no-skills",
			"--no-prompt-templates", "--no-tools", "-e", path.join(root, "files/home/.pi/agent/extensions/you-should-know/index.ts"),
			"-e", path.join(root, "files/home/.pi/agent/extensions/btw/index.ts"),
			"-e", path.join(root, "test/support/you_should_know_provider.ts"), "--provider", "ysk-test", "--model", "observer", "--session", file, ...prompts], {
			cwd: dir, env: { ...process.env, PI_CODING_AGENT_DIR: path.join(dir, "agent"), YSK_FIXTURE_REAL_JEV: "", YSK_FIXTURE_REAL_LUNA: "" }, timeout: 30_000,
		});
		if (!existsSync(file)) return [];
		return readFileSync(file, "utf8").trim().split("\n").map((line) => JSON.parse(line));
	};
	try { run(prompt); } finally { rmSync(dir, { recursive: true, force: true }); }
}
const entries = (rows, type) => rows.filter((r) => r.customType === type);

test("real SDK side conversations: isolated models/tools, snapshot, history, resume and no main injection", () => fixture((run) => {
	let rows = run("Delete database before checking backup");
	const original = entries(rows, "you-should-know-note").at(-1).data;
	assert.ok(original.id); assert.match(original.source, /backup/);
	rows = run("/ysk-chat Why is this risky?");
	const requests = entries(rows, "side-chat-fixture-request");
	const chat = requests.at(-1).data;
	assert.equal(chat.model, "gpt-6-luna"); assert.deepEqual(chat.tools, []);
	assert.match(chat.system, /11th-grade reading level or less/); assert.match(chat.source, /Original text-only snapshot/);
	assert.equal(entries(rows, "ysk-chat-turn").length, 1);
	assert.equal(entries(rows, "you-should-know-usage").length, 3);
	rows = run("/btw What should I check next?");
	const generic = entries(rows, "side-chat-fixture-request").at(-1).data;
	assert.equal(generic.model, "observer"); assert.deepEqual(generic.tools.sort(), ["bash", "edit", "read", "write"]);
	assert.equal(entries(rows, "btw-chat-turn").length, 1);
	assert.ok(!generic.source.includes("Why is this risky?"), "YSK side messages do not leak into the main seed");
	rows = run("/ysk-chat Explain the consequences.");
	assert.equal(entries(rows, "ysk-chat-turn").length, 2);
	const followup = entries(rows, "side-chat-fixture-request").at(-1).data;
	assert.match(followup.source, /Why is this risky/); assert.ok(!followup.source.includes("What should I check next?"));
	assert.equal(rows.filter((r) => r.message?.role === "user").length, 1);
	assert.equal(rows.filter((r) => r.message?.role === "assistant").length, 1);
	rows = run("/btw --new Start a fresh side thread");
	assert.equal(entries(rows, "btw-chat-reset").length, 1);
	assert.ok(!entries(rows, "side-chat-fixture-request").at(-1).data.source.includes("What should I check next?"));
	rows = run("/ysk-dismiss", "/ysk-chat Explain again");
	assert.equal(WarningInbox.restore(rows).pending.length, 0);
	assert.equal(entries(rows, "ysk-chat-turn").length, 2, "dismissed warning cannot silently use main model/context");
}));

test("no current warning means YSK chat makes no model calls", () => fixture((run) => {
	const rows = run("/ysk-chat What is wrong?");
	assert.equal(entries(rows, "side-chat-fixture-request").length, 0);
	assert.equal(entries(rows, "ysk-chat-turn").length, 0);
}));

test("managed configuration removes the old BTW package and does not enable Armin's original command too", () => {
	const settings = JSON.parse(readFileSync(path.join(root, "files/home/.pi/agent/settings.json"), "utf8"));
	assert.equal(settings.packages.some((p) => typeof p === "string" && /pi-btw/.test(p)), false);
	assert.equal(settings.packages.some((p) => typeof p === "object" && p.extensions?.includes("extensions/btw.ts")), false);
});
