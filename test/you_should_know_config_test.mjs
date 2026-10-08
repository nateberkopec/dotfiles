import assert from "node:assert/strict";
import { test } from "node:test";
import { globalThreshold } from "../files/home/.pi/agent/extensions/you-should-know/config.ts";

for (const [raw, expected, invalid] of [
	[undefined, 0.85, false],
	["0", 0, false],
	["1", 1, false],
	["0.5", 0.5, false],
	[" .25 ", 0.25, false],
	["", 0.85, true],
	[" ", 0.85, true],
	["NaN", 0.85, true],
	["Infinity", 0.85, true],
	["-0.1", 0.85, true],
	["1.01", 0.85, true],
	["no", 0.85, true],
])
	test(`global confidence configuration: ${JSON.stringify(raw)}`, () => {
		const prior = process.env.YSK_CONFIDENCE_THRESHOLD,
			notices = [];

		try {
			if (raw === undefined) delete process.env.YSK_CONFIDENCE_THRESHOLD;
			else process.env.YSK_CONFIDENCE_THRESHOLD = raw;
			assert.equal(
				globalThreshold((message) => notices.push(message)),
				expected,
			);
			assert.equal(notices.length, invalid ? 1 : 0);

			if (invalid) assert.match(notices[0], /YSK_CONFIDENCE_THRESHOLD.*0 to 1/);
		} finally {
			if (prior === undefined) delete process.env.YSK_CONFIDENCE_THRESHOLD;
			else process.env.YSK_CONFIDENCE_THRESHOLD = prior;
		}
	});
