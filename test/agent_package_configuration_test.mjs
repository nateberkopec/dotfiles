import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const settings = JSON.parse(readFileSync(new URL("../files/home/.pi/agent/settings.json", import.meta.url)));

test("managed settings use agent-stuff main for Claude Code", () => {
	const packages = settings.packages.filter((p) => /agent-stuff/.test(p.source ?? p));
	assert.equal(packages.length, 1);
	assert.equal(packages[0].source, "git:github.com/nateberkopec/agent-stuff@main");
	assert.equal(settings.packages.some((p) => /pi-claude-code/.test(p.source ?? p)), false);
	assert.deepEqual(packages[0].skills, []);
});

test("managed configuration removes the old BTW package and does not enable Armin's original command too", () => {
	assert.equal(
		settings.packages.some((p) => /pi-btw/.test(p.source ?? p)),
		false,
	);
	assert.equal(
		settings.packages.some((p) => p.extensions?.includes("extensions/btw.ts")),
		false,
	);
});
