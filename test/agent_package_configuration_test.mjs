import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const settings = JSON.parse(readFileSync(new URL("../files/home/.pi/agent/settings.json", import.meta.url)));

test("managed settings pin the Claude Code packages without Meridian", () => {
	const packages = settings.packages.filter((p) => /agent-stuff/.test(p.source ?? p));
	assert.equal(packages.length, 1);
	assert.equal(packages[0].source, "git:github.com/nateberkopec/agent-stuff@2a356dd950e77185947374f4c4f9fbe218b13a4e");
	assert.ok(settings.packages.includes("git:github.com/nateberkopec/pi-claude-code@477e17d1b3050dee18f17ce7d99f415bdd25919e"));
	assert.deepEqual(packages[0].skills, []);
	const meridian = settings.packages.filter((p) => /meridian/.test(p.source ?? p));
	assert.deepEqual(meridian, []);
	assert.equal(
		settings.extensions.some((extension) => /meridian/.test(extension)),
		false,
	);
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
