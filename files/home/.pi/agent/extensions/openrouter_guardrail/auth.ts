import { OPENROUTER_BASE_URL, SECRET_TIMEOUT_MS } from "./config";
import { readOpenRouterApiKey } from "./secrets";

export async function readValidOpenRouterEnvApiKey() {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (apiKey && (await openRouterApiKeyValid(apiKey))) return apiKey;
}

export async function readValidOpenRouterApiKey(secretTimeoutMs = SECRET_TIMEOUT_MS) {
  const envKey = await readValidOpenRouterEnvApiKey();
  if (envKey) return envKey;

  const opKey = await readOpenRouterApiKey(secretTimeoutMs, true);
  if (opKey && (await openRouterApiKeyValid(opKey))) return opKey;
}

async function openRouterApiKeyValid(apiKey: string) {
  try {
    const response = await fetch(`${OPENROUTER_BASE_URL}/auth/key`, {
      headers: { Authorization: `Bearer ${apiKey}` },
      signal: AbortSignal.timeout(2_000),
    });

    return response.ok;
  } catch {
    return false;
  }
}
