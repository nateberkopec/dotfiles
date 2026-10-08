import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { Value } from "typebox/value";
import { CUSTOM_TYPE, MIN_GENERATION_MS, type AggregateStats, type ModelRef, type ToksecEntry } from "./types.ts";

export function sameModel(a: ModelRef | undefined, b: ModelRef | undefined): boolean {
	return Boolean(a && b && a.provider === b.provider && a.id === b.id);
}

export function currentModel(ctx: ExtensionContext): ModelRef | undefined {
	const model = ctx.model;

	if (!model) return undefined;

	return { provider: model.provider, id: model.id };
}

export function zeroStats(): AggregateStats {
	return { count: 0, outputTokens: 0, generationMs: 0, ttftMs: 0 };
}

export function addSample(
	stats: AggregateStats,
	sample: Pick<ToksecEntry, "outputTokens" | "generationMs" | "ttftMs">,
): void {
	if (!Number.isFinite(sample.outputTokens) || sample.outputTokens <= 0) return;

	if (!Number.isFinite(sample.generationMs) || sample.generationMs < MIN_GENERATION_MS) return;

	if (!Number.isFinite(sample.ttftMs) || sample.ttftMs < 0) return;

	stats.latest = { outputTokens: sample.outputTokens, generationMs: sample.generationMs, ttftMs: sample.ttftMs };
	stats.count += 1;
	stats.outputTokens += sample.outputTokens;
	stats.generationMs += sample.generationMs;
	stats.ttftMs += sample.ttftMs;
}

const Sample = Type.Object({
	version: Type.Literal(1),
	kind: Type.Literal("sample"),
	provider: Type.String(),
	modelId: Type.String(),
	outputTokens: Type.Number(),
	generationMs: Type.Number(),
	ttftMs: Type.Number(),
});

function isToksecEntry(data: unknown): data is ToksecEntry {
	return Value.Check(Sample, data);
}

export function rebuildStats(ctx: ExtensionContext): AggregateStats {
	const stats = zeroStats();

	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type !== "custom" || entry.customType !== CUSTOM_TYPE) continue;

		if (!isToksecEntry(entry.data)) continue;
		addSample(stats, entry.data);
	}

	return stats;
}
