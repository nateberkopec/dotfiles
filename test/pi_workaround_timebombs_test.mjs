import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, realpathSync, rmSync, mkdirSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { assertOverridesNeeded, assertWrapperNeeded } from "../tools/pi_workaround_timebombs.mjs";

const agent = new URL("../files/home/.pi/agent/", import.meta.url);

const settings = JSON.parse(readFileSync(new URL("settings.json", agent), "utf8"));

const pins = JSON.parse(readFileSync(new URL("npm-overrides.json", agent), "utf8"));

const install = execFileSync("mise", ["where", "npm:@earendil-works/pi-coding-agent"], { encoding: "utf8" }).trim();

const requirePi = createRequire(
	realpathSync(join(install, "node_modules/@earendil-works/pi-coding-agent/package.json")),
);

const semver = requirePi("semver");

function aube(args, options = {}) {
	return execFileSync("aube", args, { encoding: "utf8", timeout: 120_000, ...options });
}

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
		mkdirSync(fixture);
		mkdirSync(join(dir, "install"));
		writeFileSync(join(dir, "install/package.json"), "{}");
		writeFileSync(join(fixture, "package.json"), JSON.stringify({ name: "pi-timebomb-fixture", version: "1.0.0" }));

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
				"--offline",
				"--ignore-scripts",
			],
			{ cwd: dir, encoding: "utf8", timeout: 30_000 },
		);

		assertWrapperNeeded(result);
	});
});

test("timebomb: the pinned adapter still requires SDK overrides", () => {
	const adapter = settings.packages.find((entry) => entry.startsWith("npm:pi-mcp-adapter@"))?.slice(4);
	assert(adapter, "Expected a pinned MCP adapter");
	const manifest = JSON.parse(aube(["view", adapter, "--json"]));

	// An unsafe declared range is already enough to prove that pins remain necessary.
	if (
		Object.entries(pins).some(
			([name, fixed]) =>
				manifest.dependencies?.[name] &&
				semver.intersects(manifest.dependencies[name], `<${fixed}`, { includePrerelease: true }),
		)
	)
		return;

	withDirectory((dir) => {
		writeFileSync(join(dir, "package.json"), "{}");
		aube(
			[
				"__aube-shim",
				"npm",
				"install",
				adapter,
				"--prefix",
				dir,
				"--ignore-scripts",
				"--config.auto-install-peers=false",
				"--config.strict-peer-dependencies=false",
			],
			{ cwd: dir },
		);
		const tree = JSON.parse(aube(["list", "--json", "--depth", "Infinity", "--dir", dir]));
		assertOverridesNeeded(tree, pins, semver);
	});
});

test("timebomb explodes when Aube becomes compatible; other probe failures are not accepted as evidence", () => {
	assertWrapperNeeded({ status: 46, stderr: "Unsupported --legacy-peer-deps" });
	assert.throws(() => assertWrapperNeeded({ status: 0, stderr: "" }), /TIMEBOMB:.*Remove pi-npm.sh/);
	assert.throws(() => assertWrapperNeeded({ status: 1, stderr: "Network unavailable" }), /different reason/);
	assert.throws(() => assertWrapperNeeded({ status: null, stderr: "" }), /could not start/);
});

test("timebomb detects fixed, nested-vulnerable, and no-longer-used SDK dependencies", () => {
	const native = (version) => [
		{ dependencies: { "pi-mcp-adapter": { dependencies: { "@modelcontextprotocol/client": { version } } } } },
	];

	assertOverridesNeeded(native("2.0.0"), pins, semver);
	assert.throws(() => assertOverridesNeeded(native("2.2.0"), pins, semver), /TIMEBOMB:.*Remove npm-overrides.json/);
	const nested = native("2.2.0");
	nested[0].dependencies["pi-mcp-adapter"].dependencies.other = {
		dependencies: { "@modelcontextprotocol/client": { version: "2.0.0" } },
	};
	assertOverridesNeeded(nested, pins, semver);
	assert.throws(() => assertOverridesNeeded([{ dependencies: {} }], pins, semver), /TIMEBOMB/);
	assert.throws(() => assertOverridesNeeded([], pins, semver), /no native dependency tree/);
});
