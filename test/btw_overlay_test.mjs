import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

const root = fileURLToPath(new URL("../", import.meta.url));

test("shared overlay frames and pads every real Markdown row, including blank, wrapped, Unicode and code rows", () => {
	const dir = mkdtempSync(path.join(tmpdir(), "btw-overlay-"));
	const file = path.join(dir, "session.jsonl");

	try {
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
				path.join(root, "test/support/you_should_know_provider.ts"),
				"-e",
				path.join(root, "test/support/btw_overlay.ts"),
				"--provider",
				"ysk-test",
				"--model",
				"observer",
				"--session",
				file,
				"Initialize the synthetic rendering fixture.",
				"/overlay-render-test",
			],
			{
				cwd: dir,
				env: {
					...process.env,
					PI_CODING_AGENT_DIR: path.join(dir, "agent"),
					YSK_FIXTURE_REAL_JEV: "",
					YSK_FIXTURE_REAL_LUNA: "",
				},
				timeout: 30_000,
			},
		);

		const rows = readFileSync(file, "utf8")
			.trim()
			.split("\n")
			.map((line) => JSON.parse(line));

		const proof = rows.find((r) => r.customType === "btw-overlay-proof")?.data;
		assert.deepEqual(proof?.failures, []);
		assert.equal(proof?.cases, 15);
	} finally {
		rmSync(dir, { recursive: true, force: true });
	}
});
