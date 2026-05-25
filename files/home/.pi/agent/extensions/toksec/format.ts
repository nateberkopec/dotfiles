import type { AggregateStats } from "./types.ts";

const STATUS_EMPTY = "tok/s --- · TTFT --.-s";

function formatRate(tokens: number, ms: number): string {
	if (tokens <= 0 || ms <= 0) return "---";
	const rate = Math.round(tokens / (ms / 1000));
	return String(Math.min(999, Math.max(0, rate))).padStart(3, " ");
}

function formatTtft(ms: number, count: number): string {
	if (count <= 0 || ms <= 0) return "--.-";
	const seconds = Math.min(99.9, ms / count / 1000);
	return seconds.toFixed(1).padStart(4, " ");
}

export function formatStatus(stats: AggregateStats): string {
	if (stats.count === 0) return STATUS_EMPTY;
	return `tok/s ${formatRate(stats.outputTokens, stats.generationMs)} · TTFT ${formatTtft(stats.ttftMs, stats.count)}s`;
}
