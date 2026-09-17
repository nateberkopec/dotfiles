import type { AggregateStats, TimingValues } from "./types.ts";

function formatRate(tokens: number, ms: number): string {
	if (tokens <= 0 || ms <= 0) return "---";
	return String(Math.round(tokens / (ms / 1000)));
}

function formatDuration(ms: number | undefined): string {
	if (ms === undefined) return "--.-s";
	return ms < 60_000 ? `${(ms / 1000).toFixed(1)}s` : `${(ms / 60_000).toFixed(1)}m`;
}

export function formatStatus(stats: AggregateStats, tbht?: TimingValues): string {
	const latest = stats.latest;
	const rate = latest ? formatRate(latest.outputTokens, latest.generationMs) : "---";
	const averageRate = formatRate(stats.outputTokens, stats.generationMs);
	const averageTtft = stats.count > 0 ? stats.ttftMs / stats.count : undefined;
	return `tok/s ${rate} (${averageRate}) · TTFT ${formatDuration(latest?.ttftMs)} (${formatDuration(averageTtft)}) · TBHT ${formatDuration(tbht?.latest)} (${formatDuration(tbht?.average)})`;
}
