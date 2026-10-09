import assert from "node:assert/strict";

export function assertWrapperNeeded(...results) {
	const failures = results.filter((result) => result.status !== 0);
	assert(
		failures.length > 0,
		"TIMEBOMB: Aube accepts Pi's native install arguments. Remove pi-npm.sh, restore the Aube-backed npmCommand, and delete this check.",
	);

	for (const result of failures) {
		assert.notEqual(result.status, null, "Aube compatibility probe timed out or could not start");
		assert.match(
			result.stderr,
			/--legacy-peer-deps|--omit/,
			"Aube probe failed for a different reason; compatibility is unverified",
		);
	}
}

export function assertOverridesNeeded(tree, pins, semver) {
	const versions = [];

	function visit(dependencies = {}) {
		for (const [name, dependency] of Object.entries(dependencies)) {
			if (name in pins) {
				assert(semver.valid(dependency.version), `Invalid native SDK version: ${name}@${dependency.version}`);
				versions.push([name, dependency.version]);
			}

			visit(dependency.dependencies);
		}
	}

	assert(Array.isArray(tree) && tree.length > 0, "Aube returned no native dependency tree");

	for (const project of tree) visit(project.dependencies);
	assert(
		versions.some(([name, version]) => semver.lt(version, pins[name])),
		"TIMEBOMB: The pinned adapter installs without vulnerable SDK copies or overrides. Remove npm-overrides.json, its helper and tests, SDK release-age exemptions, and the managed pins from the live npm/package.json.",
	);
}
