import {
  DEFAULT_GUARDRAIL_NAME,
  OPENROUTER_BASE_URL,
} from "./config";

export async function fetchGuardrail(provisioningKey: string) {
  const response = await fetch(`${OPENROUTER_BASE_URL}/guardrails`, {
    headers: { Authorization: `Bearer ${provisioningKey}` },
  });
  if (!response.ok) throw new Error(`guardrails API returned ${response.status}`);

  const payload = await response.json();
  const guardrailName = process.env.OPENROUTER_GUARDRAIL_NAME ?? DEFAULT_GUARDRAIL_NAME;
  const guardrail = payload?.data?.find((candidate: any) => candidate.name === guardrailName);
  if (!guardrail) throw new Error(`guardrail not found: ${guardrailName}`);

  return {
    name: guardrail.name,
    allowedModels: uniqueSorted(guardrail.allowed_models ?? []),
    allowedProviders: uniqueSorted(guardrail.allowed_providers ?? []),
  };
}

export async function fetchOpenRouterModels() {
  const response = await fetch(`${OPENROUTER_BASE_URL}/models`);
  if (!response.ok) throw new Error(`models API returned ${response.status}`);

  const payload = await response.json();
  return Array.isArray(payload?.data) ? payload.data : [];
}

function uniqueSorted(values: unknown[]) {
  return Array.from(new Set(values.map(String).filter(Boolean))).sort();
}
