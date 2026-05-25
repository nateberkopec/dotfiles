import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readValidOpenRouterApiKey } from "./auth";
import type { ModelCacheState } from "./config";
import {
  errorMessage,
  formatRow,
  formatRows,
  openRouterAuthMessage,
  parseLimit,
} from "./format";
import { getPerformanceRows } from "./performance";
import { refreshModelCache, registerGuardrailedOpenRouter } from "./provider";
import { switchToEndpointRoute } from "./route";
import { readOpenRouterProvisioningKey } from "./secrets";

export function registerCommands(pi: ExtensionAPI, state: ModelCacheState) {
  pi.registerCommand("or-refresh", {
    description: "Refresh guardrailed OpenRouter models from the configured OpenRouter guardrail",
    handler: async (_args: string, ctx: any) => refreshModels(pi, state, ctx),
  });

  pi.registerCommand("or-speed", {
    description: "Show guardrailed OpenRouter endpoint throughput and optionally switch to a provider route",
    handler: async (args: string, ctx: any) => showSpeed(pi, state, args, ctx),
  });
}

async function refreshModels(pi: ExtensionAPI, state: ModelCacheState, ctx: any) {
  const apiKey = await readValidOpenRouterApiKey();
  const provisioningKey = await readOpenRouterProvisioningKey();

  if (!apiKey || !provisioningKey) {
    ctx.ui.notify(openRouterAuthMessage(), "error");
    return;
  }

  try {
    const cache = await refreshModelCache(provisioningKey);
    state.setLatest(cache);
    registerGuardrailedOpenRouter(pi, cache, apiKey);
    ctx.ui.notify(`OpenRouter guardrail refreshed: ${cache.models.length} models.`, "info");
  } catch (error) {
    ctx.ui.notify(`OpenRouter guardrail refresh failed: ${errorMessage(error)}`, "error");
  }
}

async function showSpeed(pi: ExtensionAPI, state: ModelCacheState, args: string, ctx: any) {
  const apiKey = await readValidOpenRouterApiKey();
  if (!apiKey) {
    ctx.ui.notify(openRouterAuthMessage(), "error");
    return;
  }

  const modelCache = state.getLatest();
  if (!modelCache) {
    ctx.ui.notify("No OpenRouter guardrail model cache yet. Run /or-refresh after unlocking 1Password.", "error");
    return;
  }

  const provisioningKey = await readOpenRouterProvisioningKey();
  if (!provisioningKey) {
    ctx.ui.notify(openRouterAuthMessage(), "error");
    return;
  }

  await showSpeedRows(pi, ctx, modelCache, apiKey, provisioningKey, args);
}

async function showSpeedRows(
  pi: ExtensionAPI,
  ctx: any,
  modelCache: any,
  apiKey: string,
  provisioningKey: string,
  args: string,
) {
  const forceRefresh = /(^|\s)(refresh|--refresh)(\s|$)/.test(args ?? "");
  const listOnly = /(^|\s)(list|--list)(\s|$)/.test(args ?? "");
  const rows = await getPerformanceRows(modelCache, provisioningKey, forceRefresh);
  const topRows = rows.sort(compareRowsByThroughput).slice(0, parseLimit(args) ?? 30);

  if (topRows.length === 0) {
    ctx.ui.notify("No guardrailed OpenRouter endpoints are available.", "error");
  } else if (listOnly || !ctx.hasUI) {
    ctx.ui.notify(formatRows(topRows), "info");
  } else {
    await selectSpeedRow(pi, ctx, modelCache, apiKey, topRows);
  }
}

function compareRowsByThroughput(a: any, b: any) {
  if (Number.isFinite(a.throughput_p50_tps) && Number.isFinite(b.throughput_p50_tps)) {
    return b.throughput_p50_tps - a.throughput_p50_tps;
  }
  if (Number.isFinite(a.throughput_p50_tps)) return -1;
  if (Number.isFinite(b.throughput_p50_tps)) return 1;
  return a.model.localeCompare(b.model) || a.provider.localeCompare(b.provider);
}

async function selectSpeedRow(pi: ExtensionAPI, ctx: any, modelCache: any, apiKey: string, rows: any[]) {
  const choices = rows.map((row, index) => `${index + 1}. ${formatRow(row)}`);
  const selected = await ctx.ui.select("OpenRouter endpoint by throughput:", choices);
  if (!selected) return;

  const row = rows[choices.indexOf(selected)];
  if (row) await switchToEndpointRoute(pi, ctx, modelCache, row, apiKey);
}
