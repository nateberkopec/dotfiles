import { Type } from "typebox";
import { Value } from "typebox/value";

export type Observer = "jev" | "luna";

export interface UsageRecord {
	provider: Observer;
	input: number;
	output: number;
	cost?: number;
}

interface Totals {
	calls: number;
	input: number;
	output: number;
	cost: number;
	unknownCost: boolean;
}

const empty = (): Totals => ({ calls: 0, input: 0, output: 0, cost: 0, unknownCost: false });

const Metric = Type.Number({ minimum: 0 });

export const UsageRecord = Type.Object({
	provider: Type.Union([Type.Literal("jev"), Type.Literal("luna")]),
	input: Metric,
	output: Metric,
	cost: Type.Optional(Metric),
});

const finite = (value: unknown): value is number => Value.Check(Metric, value);

export function usageRecord(provider: Observer, usage: any, interrupted = false): UsageRecord {
	const input = provider === "jev" ? usage?.input_tokens : usage?.input;
	const output = provider === "jev" ? usage?.output_tokens : usage?.output;
	// Jev charges input only. Luna's SDK estimate includes cache/reasoning pricing.
	const cost = provider === "jev" ? (finite(input) ? (input * 0.042) / 1_000_000 : undefined) : usage?.cost?.total;

	// An interrupted SDK stream may retain initialization zeros without receiving usage.
	const placeholder =
		provider === "luna" &&
		interrupted &&
		!(finite(cost) && cost > 0) &&
		!["input", "output", "cacheRead", "cacheWrite", "totalTokens", "reasoning"].some(
			(key) => finite(usage?.[key]) && usage[key] > 0,
		);

	return {
		provider,
		input: finite(input) ? input : 0,
		output: finite(output) ? output : 0,
		cost: finite(cost) && !placeholder ? cost : undefined,
	};
}

export class UsageLedger {
	readonly totals = { jev: empty(), luna: empty() };
	add(record: UsageRecord) {
		if (!Value.Check(UsageRecord, record)) return;
		const total = this.totals[record.provider];
		total.calls++;
		total.input += record.input;
		total.output += record.output;

		if (finite(record.cost)) total.cost += record.cost;
		else total.unknownCost = true;
	}
	footer(): string {
		const part = (name: string, total: Totals) =>
			`${name} ~$${total.unknownCost ? "?" : (Math.ceil(total.cost * 1000) / 1000).toFixed(3)} (${total.calls})`;

		return `YSK ${part("Jev", this.totals.jev)} ${part("Luna", this.totals.luna)}`;
	}
}
