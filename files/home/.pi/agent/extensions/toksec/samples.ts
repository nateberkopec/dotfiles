import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
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

function isToksecEntry(data: unknown): data is ToksecEntry {
	if (!data || typeof data !== "object") return false;
	const entry = data as Partial<ToksecEntry>;
	return (
		entry.version === 1 &&
		entry.kind === "sample" &&
		typeof entry.provider === "string" &&
		typeof entry.modelId === "string" &&
		typeof entry.outputTokens === "number" &&
		typeof entry.generationMs === "number" &&
		typeof entry.ttftMs === "number"
	);
}

export function rebuildStats(ctx: ExtensionContext): AggregateStats {
	const stats = zeroStats();
	for (const entry of ctx.sessionManager.getBranch()) {
		const custom = entry as { type?: string; customType?: string; data?: unknown };
		if (custom.type !== "custom" || custom.customType !== CUSTOM_TYPE) continue;
		if (!isToksecEntry(custom.data)) continue;
		addSample(stats, custom.data);
	}

	return stats;
}
