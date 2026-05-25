import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  OPENROUTER_BASE_URL,
  type ModelCache,
  type PerformanceRow,
  type PiModel,
} from "./config";
import { formatNumber } from "./format";

export async function switchToEndpointRoute(
  pi: ExtensionAPI,
  ctx: any,
  modelCache: ModelCache,
  row: PerformanceRow,
  apiKey: string,
) {
  const baseModel = modelCache.models.find((model) => model.id === row.model);
  if (!baseModel) {
    ctx.ui.notify(`Model ${row.model} is not in the current guardrail cache.`, "error");
    return;
  }

  pi.registerProvider("openrouter-selected", {
    name: "OpenRouter selected endpoint",
    baseUrl: OPENROUTER_BASE_URL,
    api: "openai-completions",
    apiKey,
    models: [routedModel(baseModel, row)],
  });

  const model = ctx.modelRegistry.find("openrouter-selected", row.model);
  if (!model) {
    ctx.ui.notify("Registered the selected route, but Pi did not expose it yet. Try /model openrouter-selected.", "error");
    return;
  }

  const ok = await pi.setModel(model);
  const speed = formatNumber(row.throughput_p50_tps);
  if (ok) {
    ctx.ui.notify(`Selected ${row.model} via ${row.provider} (${speed} tok/s).`, "info");
  } else {
    ctx.ui.notify("Could not select OpenRouter route because no API key was available.", "error");
  }
}

function routedModel(baseModel: PiModel, row: PerformanceRow): PiModel {
  return {
    ...baseModel,
    name: `${baseModel.name} via ${row.provider} (${formatNumber(row.throughput_p50_tps)} tok/s)`,
    compat: {
      ...baseModel.compat,
      openRouterRouting: {
        only: [row.provider],
        allow_fallbacks: false,
      },
    },
  };
}
