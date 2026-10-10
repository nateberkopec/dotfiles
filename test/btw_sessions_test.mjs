import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import { Type } from "typebox";
import { Value } from "typebox/value";

const root = fileURLToPath(new URL("../", import.meta.url));

function fixture(run) {
	const dir = mkdtempSync(path.join(tmpdir(), "btw-sessions-")),
		file = path.join(dir, "session.jsonl");

	const prompt = (...prompts) => {
		execFileSync(
			"pi",
			[
				"--offline",
				"--mode",
				"json",
				"--no-extensions",
				"--no-context-files",
				"--no-skills",
				"--no-prompt-templates",
				"--no-tools",
				"-e",
				path.join(root, "files/home/.pi/agent/extensions/btw/index.ts"),
				"-e",
				path.join(root, "test/support/btw_provider.ts"),
				"--provider",
				"btw-test",
				"--model",
				"assistant",
				"--session",
				file,
				...prompts,
			],
			{
				cwd: dir,
				env: {
					...process.env,
					PI_CODING_AGENT_DIR: path.join(dir, "agent"),
				},
				timeout: 30_000,
			},
		);

		if (!existsSync(file)) return [];

		return readFileSync(file, "utf8")
			.trim()
			.split("\n")
			.map((line) => JSON.parse(line));
	};

	try {
		run(prompt);
	} finally {
		rmSync(dir, { recursive: true, force: true });
	}
}

const entries = (rows, type) => rows.filter((r) => r.customType === type);

test("real SDK side conversations: isolated models/tools, snapshot, history, resume and no main injection", () =>
	fixture((run) => {
		run("Check the database backup");
		let rows = run("/btw What should I check next?");
		const generic = entries(rows, "side-chat-fixture-request").at(-1).data;
		assert.equal(generic.model, "assistant");
		assert.match(generic.source, /Check the database backup/);
		assert.deepEqual(generic.tools.sort(), ["bash", "edit", "read", "write"]);
		assert.equal(entries(rows, "btw-chat-turn").length, 1);
		rows = run("/btw Explain the consequences.");
		assert.equal(entries(rows, "btw-chat-turn").length, 2);
		const followup = entries(rows, "side-chat-fixture-request").at(-1).data;
		assert.match(followup.source, /What should I check next/);
		assert.equal(rows.filter((r) => r.message?.role === "user").length, 1);
		assert.equal(rows.filter((r) => r.message?.role === "assistant").length, 1);
		rows = run("/btw --new Start a fresh side thread");
		assert.equal(entries(rows, "btw-chat-reset").length, 1);
		assert.ok(!entries(rows, "side-chat-fixture-request").at(-1).data.source.includes("What should I check next?"));
	}));

test("managed configuration removes the old BTW package and does not enable Armin's original command too", () => {
	const settings = JSON.parse(readFileSync(path.join(root, "files/home/.pi/agent/settings.json"), "utf8"));
	assert.equal(
		settings.packages.some((p) => Value.Check(Type.String(), p) && /pi-btw/.test(p)),
		false,
	);
	assert.equal(
		settings.packages.some(
			(p) =>
				Value.Check(Type.Object({ extensions: Type.Array(Type.String()) }), p) &&
				p.extensions.includes("extensions/btw.ts"),
		),
		false,
	);
});
