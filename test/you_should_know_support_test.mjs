import assert from "node:assert/strict";
import { test } from "node:test";
import { decide, JEV_MODEL, JEV_URL } from "../files/home/.pi/agent/extensions/you-should-know/jev.ts";
import { UsageLedger, usageRecord } from "../files/home/.pi/agent/extensions/you-should-know/usage.ts";
import { ObserverUI } from "../files/home/.pi/agent/extensions/you-should-know/ui.ts";

process.env.TYPESAFE_API_KEY = "fixture-not-a-secret";
const answer = () => ({ model: JEV_MODEL, answers: {
	interrupt: { type: "choice", choice: "warn", confidence: 1, probabilities: { warn: 1, quiet: 0 } },
	category: { type: "choice", choice: "verification", confidence: 1, probabilities: { verification: 1, data_loss: 0, security: 0, none: 0 } },
} });
test("pinned native Jev batches once, refuses redirects, and never logs HTTP bodies", async () => {
	const calls = [];
	await decide("input", new AbortController().signal, async (url, options) => {
		calls.push({ url, options }); return new Response(JSON.stringify(answer()));
	});
	assert.equal(calls.length, 1); assert.equal(calls[0].url, JEV_URL); assert.equal(calls[0].options.redirect, "error");
	assert.equal(Object.keys(JSON.parse(calls[0].options.body).questions).length, 2);
	for (const status of [401, 429, 500]) {
		await assert.rejects(decide("input", new AbortController().signal, async () => new Response("PRIVATE body", { status })), new RegExp(`^Error: Jev HTTP ${status}`));
	}
});
test("missing key prevents all network access", async () => {
	const prior = process.env.TYPESAFE_API_KEY; delete process.env.TYPESAFE_API_KEY;
	try { await assert.rejects(decide("input", new AbortController().signal, () => { throw Error("network must not run"); }), /TYPESAFE_API_KEY/); }
	finally { process.env.TYPESAFE_API_KEY = prior; }
});
for (const [name, mutate] of [
	["model", (d) => d.model = "replacement"],
	["NaN", (d) => d.answers.interrupt.probabilities.warn = NaN],
	["negative", (d) => d.answers.interrupt.probabilities.warn = -1],
	["over one", (d) => d.answers.interrupt.probabilities.warn = 1.1],
	["bad sum", (d) => d.answers.interrupt.probabilities.quiet = 0.5],
	["confidence", (d) => d.answers.interrupt.confidence = "high"],
	["category", (d) => d.answers.category.choice = "unknown"],
]) test(`invalid ${name} fails closed`, async () => {
	const data = answer(); mutate(data);
	await assert.rejects(decide("input", new AbortController().signal, async () => new Response(JSON.stringify(data))), /invalid probabilities/);
});
test("costs accumulate per provider and ceil only at display; missing usage is unknown", () => {
	const ledger = new UsageLedger();
	ledger.add(usageRecord("jev", { input_tokens: 1000, output_tokens: 99999 }));
	ledger.add(usageRecord("jev", { input_tokens: 1000 }));
	ledger.add(usageRecord("luna", { cost: { total: 0.001001 } }));
	assert.equal(ledger.footer(), "YSK Jev ~$0.001 (2) Luna ~$0.002 (1)");
	assert.equal(ledger.totals.jev.cost, 0.000084);
	ledger.add(usageRecord("luna", {})); assert.match(ledger.footer(), /Luna ~\$\?/);
	ledger.add({ provider: "other" }); assert.equal(ledger.totals.jev.calls, 2);
});
test("interrupted SDK placeholder zeros are unknown, but reported or genuine zero usage is preserved", () => {
	const zero = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0,
		cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } };
	assert.equal(usageRecord("luna", zero, true).cost, undefined);
	assert.equal(usageRecord("luna", zero).cost, 0);
	assert.equal(usageRecord("luna", { ...zero, input: 100, totalTokens: 100 }, true).cost, 0);
	assert.equal(usageRecord("luna", { ...zero, cost: { total: 0.001 } }, true).cost, 0.001);
});

test("dim costs above native footer, no padding, spinner animates and stops", async () => {
	let component, options;
	const theme = { fg: (color, text) => { assert.equal(color, "dim"); return text; } };
	const ctx = { mode: "tui", ui: { setWidget: (_key, factory, opts) => { component = factory({}, theme); options = opts; } } };
	const ui = new ObserverUI(ctx, new UsageLedger()); ui.footer();
	assert.equal(options.placement, "belowEditor"); assert.match(component.render(80)[0], /^· YSK/);
	assert.equal(component.render(10)[0].length, 10);
	ui.waiting(true); const first = component.render(80)[0];
	try { await new Promise((resolve) => setTimeout(resolve, 120)); assert.notEqual(component.render(80)[0], first); }
	finally { ui.waiting(false); }
	assert.match(component.render(80)[0], /^· YSK/);
});
test("no note means no message widget row", async () => {
	const calls = []; const ctx = { mode: "tui", ui: { setWidget: (...args) => calls.push(args) } };
	await new ObserverUI(ctx, new UsageLedger()).note("", () => true);
	assert.equal(calls[0][1], undefined);
});
