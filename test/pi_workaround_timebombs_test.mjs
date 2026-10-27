import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, rmSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { assertWrapperNeeded } from "../tools/pi_workaround_timebombs.mjs";

function withDirectory(run) {
	const dir = mkdtempSync(join(tmpdir(), "pi-timebomb-"));

	try {
		return run(dir);
	} finally {
		rmSync(dir, { recursive: true, force: true });
	}
}

test("timebomb: the pinned Aube still requires Pi's argument translation", () => {
	withDirectory((dir) => {
		const fixture = join(dir, "fixture");
		const development = join(dir, "development");
		mkdirSync(fixture);
		mkdirSync(development);
		writeFileSync(
			join(development, "package.json"),
			JSON.stringify({ name: "pi-timebomb-dev-only", version: "1.0.0" }),
		);
		mkdirSync(join(dir, "install"));
		writeFileSync(join(dir, "install/package.json"), "{}");
		writeFileSync(
			join(fixture, "package.json"),
			JSON.stringify({
				name: "pi-timebomb-fixture",
				version: "1.0.0",
				peerDependencies: { "pi-timebomb-host-api": "9999.0.0" },
				devDependencies: { "pi-timebomb-dev-only": `file:${development}` },
			}),
		);

		const result = spawnSync(
			"aube",
			[
				"__aube-shim",
				"npm",
				"install",
				`file:${fixture}`,
				"--prefix",
				join(dir, "install"),
				"--legacy-peer-deps",
				"--config.offline=true",
				"--ignore-scripts",
			],
			{ cwd: dir, encoding: "utf8", timeout: 30_000 },
		);

		const gitResult = spawnSync(
			"aube",
			["__aube-shim", "npm", "install", "--omit=dev", "--legacy-peer-deps", "--config.offline=true", "--ignore-scripts"],
			{ cwd: fixture, encoding: "utf8", timeout: 30_000 },
		);

		if (gitResult.status === 0)
			assert(
				!existsSync(join(fixture, "node_modules/pi-timebomb-dev-only")),
				"Aube accepted --omit but installed development packages",
			);
		assertWrapperNeeded(result, gitResult);
	});
});

test("timebomb explodes when Aube becomes compatible; other probe failures are not accepted as evidence", () => {
	assertWrapperNeeded({ status: 46, stderr: "Unsupported --legacy-peer-deps" });
	assertWrapperNeeded({ status: 0, stderr: "" }, { status: 1, stderr: "Unsupported --omit" });
	assert.throws(() => assertWrapperNeeded({ status: 0, stderr: "" }), /TIMEBOMB:.*Remove pi-npm.sh/);
	assert.throws(() => assertWrapperNeeded({ status: 1, stderr: "Network unavailable" }), /different reason/);
	assert.throws(() => assertWrapperNeeded({ status: null, stderr: "" }), /could not start/);
});
