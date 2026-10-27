import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const config = JSON.parse(readFileSync(new URL("../files/home/.paseo/config.json", import.meta.url)));

test("Paseo stays loopback-only without relay, injected tools, or voice", () => {
	assert.equal(config.version, 1);
	assert.equal(config.daemon.listen, "127.0.0.1:6767");
	assert.deepEqual(config.daemon.hostnames, ["localhost", ".localhost", "127.0.0.1"]);
	assert.deepEqual(config.daemon.relay, { enabled: false });
	assert.deepEqual(config.daemon.mcp, { enabled: false, injectIntoAgents: false });
	assert.deepEqual(config.daemon.browserTools, { enabled: false });
	assert.deepEqual(config.daemon.cors.allowedOrigins, []);
	assert.equal(config.features.dictation.enabled, false);
	assert.equal(config.features.voiceMode.enabled, false);
	assert.equal(config.features.webUi.enabled, true);
	assert.equal(config.pluginsEnabled, true);
	assert.equal(config.app.baseUrl, "http://127.0.0.1:6767");
});

test("Paseo config contains no account-specific macOS home paths", () => {
	assert.doesNotMatch(JSON.stringify(config), /\/Users\/[^/]+\//);
});

test("Paseo launches only Pi with explicit datasafe profiles and PATH-resolved commands", () => {
	const providers = config.agents.providers;
	for (const [id, mode] of [["pi", "usa-no-train"], ["pi-claude", "claude-only"]]) {
		assert.deepEqual(providers[id].command, ["pi"]);
		assert.deepEqual(providers[id].env, {
			PI_DATASAFE_MODE: mode, NONINTERACTIVE: "1", PI_SKIP_VERSION_CHECK: "1",
		});
		assert.deepEqual(providers[id].paseoTools, { enabled: false });
	}
	assert.equal(providers["pi-claude"].extends, "pi");
	for (const id of ["claude", "codex", "copilot", "opencode", "omp", "antigravity", "muse"]) {
		assert.deepEqual(providers[id], { enabled: false });
	}
	const metadata = config.agents.metadataGeneration.providers;
	assert.deepEqual(metadata, [{ provider: "pi-claude", model: "meridian/claude-haiku-4-5" }]);
});
