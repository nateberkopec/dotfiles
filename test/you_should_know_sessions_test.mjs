import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { test } from "node:test";
import { WarningInbox } from "../files/home/.pi/agent/extensions/you-should-know/inbox.ts";
import { UsageLedger } from "../files/home/.pi/agent/extensions/you-should-know/usage.ts";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));

const extension = path.join(root, "files/home/.pi/agent/extensions/you-should-know/index.ts");

const fixture = path.join(root, "test/support/you_should_know_provider.ts");

test("real terminal card: shortcut, action navigation, selected-warning Details, acknowledgments and draft preservation", () => {
	const output = execFileSync("python3", [path.join(root, "test/support/you_should_know_card.py")], {
		encoding: "utf8",
		timeout: 45_000,
	});

	assert.match(output, /PASS: real Ctrl\+; card/);
});

for (const mode of ["complete", "interrupted"])
	test(`real SDK Luna transport rejects redirects and accounts ${mode} SSE usage`, () => {
		const dir = mkdtempSync(path.join(tmpdir(), "ysk-transport-"));
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
					extension,
					"-e",
					fixture,
					"-e",
					path.join(root, "test/support/you_should_know_transport.ts"),
					"--provider",
					"ysk-test",
					"--model",
					"observer",
					"--session",
					file,
					"Delete database before checking backup",
				],
				{
					cwd: dir,
					env: {
						...process.env,
						PI_CODING_AGENT_DIR: path.join(dir, "agent"),
						YSK_TRANSPORT_FIXTURE: mode,
						YSK_FIXTURE_REAL_JEV: "",
						YSK_FIXTURE_REAL_LUNA: "1",
					},
					timeout: 30_000,
				},
			);

			const rows = readFileSync(file, "utf8")
				.trim()
				.split("\n")
				.map((line) => JSON.parse(line));

			const checks = rows.filter((e) => e.customType === "ysk-transport-check");
			assert.equal(checks.length, 2);
			assert.ok(checks.every((e) => e.data.redirect === "error"));
			const usage = rows.filter((e) => e.customType === "you-should-know-usage");
			assert.equal(usage.length, 2);
			const ledger = new UsageLedger();
			usage.forEach((e) => ledger.add(e.data));

			if (mode === "interrupted") {
				assert.equal(usage[1].data.input, 0);
				assert.equal(usage[1].data.output, 0);
				assert.equal(usage[1].data.cost, undefined);
				assert.equal(ledger.totals.luna.unknownCost, true);
				assert.match(ledger.footer(), /Luna ~\$\?/);
				assert.equal(
					rows.some((e) => e.customType === "you-should-know-note" && e.data.note),
					false,
				);
			} else {
				assert.equal(usage[1].data.input, 100);
				assert.equal(usage[1].data.output, 10);
				assert.ok(usage[1].data.cost > 0);
				assert.equal(ledger.totals.luna.unknownCost, false);
				assert.match(rows.find((e) => e.customType === "you-should-know-note").data.note, /Verify the backup/);
			}
		} finally {
			rmSync(dir, { recursive: true, force: true });
		}
	});

for (const mode of ["complete", "interrupted"])
	test(`YSK side-chat actual SDK transport: ${mode}, no redirects or tools`, () => {
		const dir = mkdtempSync(path.join(tmpdir(), "ysk-chat-transport-")),
			file = path.join(dir, "session.jsonl");

		const run = (mode, prompt) =>
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
					extension,
					"-e",
					fixture,
					"-e",
					path.join(root, "test/support/you_should_know_transport.ts"),
					"--provider",
					"ysk-test",
					"--model",
					"observer",
					"--session",
					file,
					prompt,
				],
				{
					cwd: dir,
					env: {
						...process.env,
						PI_CODING_AGENT_DIR: path.join(dir, "agent"),
						YSK_TRANSPORT_FIXTURE: mode,
						YSK_FIXTURE_REAL_JEV: "",
						YSK_FIXTURE_REAL_LUNA: "1",
					},
					timeout: 30_000,
				},
			);

		try {
			run("complete", "Delete database before checking backup");
			run(mode, "/ysk-chat Explain this concern");

			const rows = readFileSync(file, "utf8")
				.trim()
				.split("\n")
				.map((line) => JSON.parse(line));

			assert.equal(rows.filter((r) => r.customType === "ysk-transport-check").length, 3);
			assert.ok(rows.filter((r) => r.customType === "ysk-transport-check").every((r) => r.data.redirect === "error"));
			const usage = rows.filter((r) => r.customType === "you-should-know-usage");
			assert.equal(usage.length, 3);
			assert.equal(rows.filter((r) => r.customType === "ysk-chat-turn").length, mode === "complete" ? 1 : 0);

			if (mode === "interrupted") assert.equal(usage.at(-1).data.cost, undefined);
			else assert.ok(usage.at(-1).data.cost > 0);
		} finally {
			rmSync(dir, { recursive: true, force: true });
		}
	});

test("real Pi CLI sessions: default-on, risk, quiet, resume, threshold and disable", () => {
	const dir = mkdtempSync(path.join(tmpdir(), "ysk-sessions-"));

	const run = (name, ...prompts) => {
		const file = path.join(dir, `${name}.jsonl`);
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
				extension,
				"-e",
				fixture,
				"--provider",
				"ysk-test",
				"--model",
				"observer",
				"--session",
				file,
				...prompts,
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

		return readFileSync(file, "utf8")
			.trim()
			.split("\n")
			.map((line) => JSON.parse(line));
	};

	const notes = (entries) => entries.filter((e) => e.customType === "you-should-know-note");
	const reviews = (entries) => entries.filter((e) => e.customType === "you-should-know-review");

	try {
		assert.equal(reviews(run("off", "/ysk-demo off", "Delete database before checking backup")).length, 0);
		const risk = run("risk", "Delete database before checking backup");
		assert.match(notes(risk)[0].data.note, /Verify the backup/);
		assert.equal(
			reviews(risk).length,
			1,
			"finalized assistant is reviewed once, not once before persistence and again after",
		);
		assert.equal(reviews(risk)[0].data.model, "jev-1.13.0", "gate is pinned independently of the main session model");
		assert.equal(risk.filter((e) => e.customType === "you-should-know-usage").length, 2);
		assert.equal(
			risk.filter((e) => e.message?.role === "assistant").length,
			1,
			"side agent never enters main transcript",
		);
		const resumed = run("risk", "Check the backup");
		assert.equal(reviews(resumed).length, 2, "enabled observer survives a real process restart");
		const disabled = run("risk", "/ysk-demo off", "Check backup again");
		assert.equal(reviews(disabled).length, 2);
		assert.equal(WarningInbox.restore(disabled).pending.length, 1, "disabling hides without discarding the warning");
		const enabled = run("risk", "/ysk-demo on");
		assert.equal(WarningInbox.restore(enabled).current.note, notes(risk)[0].data.note);
		const quiet = run("quiet", "What is 2 + 2?");
		assert.equal(reviews(quiet).length, 1);
		assert.equal(notes(quiet).length, 0);
		assert.equal(quiet.filter((e) => e.customType === "you-should-know-usage").length, 1, "quiet gate skips Luna");
		const threshold = run("threshold", "/ysk-demo .95", "What is 2 + 2?");
		assert.equal(reviews(threshold)[0].data.threshold, 0.95);
	} finally {
		rmSync(dir, { recursive: true, force: true });
	}
});
