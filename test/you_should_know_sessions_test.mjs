import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const extension = path.join(root, "files/home/.pi/agent/extensions/you-should-know.ts");
const fixture = path.join(root, "test/support/you_should_know_provider.ts");

test("real Pi CLI sessions: default-off, risk, quiet, resume, dismiss and disable", () => {
	const dir = mkdtempSync(path.join(tmpdir(), "ysk-sessions-"));
	const run = (name, ...prompts) => {
		const file = path.join(dir, `${name}.jsonl`);
		execFileSync("pi", ["--offline", "--mode", "json", "--no-extensions", "--no-context-files", "--no-skills",
			"--no-prompt-templates", "--no-tools", "-e", extension, "-e", fixture, "--provider", "ysk-test",
			"--model", "observer", "--session", file, ...prompts], {
			cwd: dir, env: { ...process.env, PI_CODING_AGENT_DIR: path.join(dir, "agent") }, timeout: 30_000,
		});
		return readFileSync(file, "utf8").trim().split("\n").map((line) => JSON.parse(line));
	};
	const notes = (entries) => entries.filter((e) => e.customType === "you-should-know-note");
	const reviews = (entries) => entries.filter((e) => e.customType === "you-should-know-review");
	try {
		assert.equal(reviews(run("off", "Delete database before checking backup")).length, 0);
		const risk = run("risk", "/you-should-know on", "Delete database before checking backup");
		assert.match(notes(risk)[0].data.note, /Verify the backup/);
		assert.equal(reviews(risk).length, 1, "finalized assistant is reviewed once, not once before persistence and again after");
		assert.equal(reviews(risk)[0].data.model, "gpt-6-luna", "observer uses Luna while the main session uses the fixture model");
		assert.equal(risk.filter((e) => e.message?.role === "assistant").length, 1, "side agent never enters main transcript");
		const resumed = run("risk", "Check the backup");
		assert.equal(reviews(resumed).length, 2, "opt-in survives a real process restart");
		const disabled = run("risk", "/you-should-know dismiss", "/you-should-know off", "Check backup again");
		assert.equal(reviews(disabled).length, 2);
		assert.equal(notes(disabled).at(-1).data.note, "");
		const quiet = run("quiet", "/you-should-know on", "What is 2 + 2?");
		assert.equal(reviews(quiet).length, 1);
		assert.equal(notes(quiet).length, 0);
	} finally { rmSync(dir, { recursive: true, force: true }); }
});
