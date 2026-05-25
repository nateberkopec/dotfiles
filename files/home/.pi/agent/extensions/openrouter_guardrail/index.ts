import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  CACHE_VERSION,
  MODEL_CACHE_TTL_MS,
  modelCachePath,
  type ModelCache,
} from "./config";
import { readValidOpenRouterEnvApiKey } from "./auth";
import { registerCommands } from "./commands";
import { readJson } from "./json_cache";
import {
  hideOpenRouter,
  refreshModelCache,
  registerGuardrailedOpenRouter,
} from "./provider";
let latestModelCache: ModelCache | undefined;

export default async function (pi: ExtensionAPI) {
  hideOpenRouter(pi);
  registerCommands(pi, {
    getLatest: () => latestModelCache,
    setLatest: (cache) => {
      latestModelCache = cache;
    },
  });

  const cached = await readJson<ModelCache>(modelCachePath);
  const listMode = process.argv.includes("--list-models");
  let apiKey = await registerCachedModels(pi, cached);

  if (!latestModelCache && listMode) {
    apiKey = apiKey ?? (await readValidOpenRouterEnvApiKey());
    const provisioningKey = apiKey ? process.env.OPENROUTER_PROVISIONING_KEY : undefined;
    if (apiKey && provisioningKey && (await refreshAndRegister(pi, provisioningKey, apiKey))) return;
  }

  void initializeOpenRouter(pi, cached, apiKey);
}

async function registerCachedModels(pi: ExtensionAPI, cached: ModelCache | undefined) {
  if (!cached || cached.version !== CACHE_VERSION || cached.models.length === 0) return;

  latestModelCache = cached;
  const apiKey = await readValidOpenRouterEnvApiKey();
  if (apiKey) registerGuardrailedOpenRouter(pi, cached, apiKey);
  return apiKey;
}

async function initializeOpenRouter(
  pi: ExtensionAPI,
  cached: ModelCache | undefined,
  apiKey: string | undefined,
) {
  apiKey = apiKey ?? (await readValidOpenRouterEnvApiKey());
  if (!apiKey || (cached && Date.now() - cached.fetchedAt < MODEL_CACHE_TTL_MS)) return;

  const provisioningKey = process.env.OPENROUTER_PROVISIONING_KEY;
  if (provisioningKey) await refreshAndRegister(pi, provisioningKey, apiKey);
}

async function refreshAndRegister(pi: ExtensionAPI, provisioningKey: string, apiKey: string) {
  try {
    const refreshed = await refreshModelCache(provisioningKey);
    latestModelCache = refreshed;
    registerGuardrailedOpenRouter(pi, refreshed, apiKey);
    return true;
  } catch {
    return false;
  }
}
