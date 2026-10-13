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
