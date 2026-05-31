import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  CACHE_VERSION,
  OPENROUTER_BASE_URL,
  modelCachePath,
  performanceCachePath,
  type ModelCache,
} from "./config";
import { fetchGuardrail, fetchOpenRouterModels } from "./guardrail_api";
import { removeJson, writeJson } from "./json_cache";
import { toPiModel } from "./pi_models";

export function hideOpenRouter(pi: ExtensionAPI) {
  pi.registerProvider("openrouter", {
    name: "OpenRouter (guardrail unavailable)",
    baseUrl: OPENROUTER_BASE_URL,
    api: "openai-completions",
    apiKey: "$OPENROUTER_API_KEY",
    models: [unavailableModel()],
  });
}

export function registerGuardrailedOpenRouter(pi: ExtensionAPI, cache: ModelCache, apiKey: string) {
  pi.registerProvider("openrouter", {
    name: `OpenRouter (${cache.guardrailName})`,
    baseUrl: OPENROUTER_BASE_URL,
    api: "openai-completions",
    apiKey,
    headers: { Authorization: `Bearer ${apiKey}` },
    models: cache.models,
  });
}

export async function refreshModelCache(provisioningKey: string) {
  const guardrail = await fetchGuardrail(provisioningKey);
  const openRouterModels = await fetchOpenRouterModels();
  const bySlug = modelSlugMap(openRouterModels);
  const modelRecords = guardrail.allowedModels.map((slug) => bySlug.get(slug) ?? { id: slug, name: slug });
  const models = modelRecords.map((model) => toPiModel(model, guardrail.allowedProviders));

  const cache = {
    version: CACHE_VERSION,
    fetchedAt: Date.now(),
    guardrailName: guardrail.name,
    allowedModels: uniqueSorted(modelRecords.map((model) => model.id)),
    allowedProviders: guardrail.allowedProviders,
    models,
  };

  await writeJson(modelCachePath, cache);
  await removeJson(performanceCachePath);
  return cache;
}

function modelSlugMap(models: any[]) {
  const bySlug = new Map<string, any>();
  for (const model of models) {
    if (model?.id) bySlug.set(model.id, model);
    if (model?.canonical_slug) bySlug.set(model.canonical_slug, model);
  }
  return bySlug;
}

function uniqueSorted(values: unknown[]) {
  return Array.from(new Set(values.map(String).filter(Boolean))).sort();
}

function unavailableModel() {
  return {
    id: "__unlock-1password-for-openrouter-guardrail",
    name: "Unlock 1Password for OpenRouter guardrail",
    reasoning: false,
    input: ["text"],
    contextWindow: 1,
    maxTokens: 1,
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
  };
}
