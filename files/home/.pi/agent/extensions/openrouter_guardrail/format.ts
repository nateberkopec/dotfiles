import type { PerformanceRow } from "./config";

export function formatRows(rows: PerformanceRow[]) {
  return rows.map((row, index) => `${index + 1}. ${formatRow(row)}`).join("\n");
}

export function formatRow(row: PerformanceRow) {
  const quantization = row.quantization ? ` ${row.quantization}` : "";
  return `${formatNumber(row.throughput_p50_tps)} tok/s | ${formatNumber(row.latency_p50_ms)} ms | ${row.provider}${quantization} | ${row.model}`;
}

export function formatNumber(value: number) {
  if (!Number.isFinite(value)) return "n/a";
  return value.toFixed(value >= 100 ? 0 : 1);
}

export function parseLimit(args: string) {
  const match = /(?:^|\s)(?:limit=|--limit\s+)(\d+)(?:\s|$)/.exec(args ?? "");
  if (!match) return undefined;

  const value = Number(match[1]);
  if (!Number.isInteger(value) || value < 1) return undefined;
  return Math.min(value, 100);
}

export function openRouterAuthMessage() {
  return "OpenRouter guardrail is unavailable. Unlock 1Password or set OPENROUTER_API_KEY and OPENROUTER_PROVISIONING_KEY.";
}

export function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}
