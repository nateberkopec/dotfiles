import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const settings = JSON.parse(readFileSync(new URL("../files/home/.pi/agent/settings.json", import.meta.url)));

test("managed settings install one pinned agent package and one Meridian package with shared skills", () => {
	const packages = settings.packages.filter((p) => /agent-stuff/.test(p.source ?? p));
	assert.equal(packages.length, 1);
	assert.match(packages[0].source, /^git:github\.com\/nateberkopec\/agent-stuff@[a-f0-9]{40}$/);
	assert.deepEqual(packages[0].skills, []);
	const meridian = settings.packages.filter((p) => /pi-meridian/.test(p.source ?? p));
	assert.deepEqual(meridian, ["npm:@nateberkopec/pi-meridian@0.1.0-beta.2"]);
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
