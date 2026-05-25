import type { PiModel } from "./config";

export function toPiModel(model: any, allowedProviders: string[]): PiModel {
  const supportedParameters = model.supported_parameters ?? [];
  const inputModalities = model.architecture?.input_modalities ?? [];
  const pricing = model.pricing ?? {};

  return {
    id: model.id,
    name: model.name ?? model.id,
    reasoning: supportsReasoning(model.id, supportedParameters),
    input: inputModalities.includes("image") ? ["text", "image"] : ["text"],
    contextWindow: Number(model.top_provider?.context_length ?? model.context_length ?? 128_000),
    maxTokens: Number(model.top_provider?.max_completion_tokens ?? 16_384),
    cost: {
      input: pricePerMillion(pricing.prompt),
      output: pricePerMillion(pricing.completion),
      cacheRead: pricePerMillion(pricing.input_cache_read),
      cacheWrite: pricePerMillion(pricing.input_cache_write),
    },
    compat: {
      cacheControlFormat: "anthropic",
      thinkingFormat: "openrouter",
      openRouterRouting: {
        only: allowedProviders,
        allow_fallbacks: false,
      },
    },
  };
}

function supportsReasoning(modelId: string, supportedParameters: string[]) {
  return (
    supportedParameters.includes("reasoning") ||
    supportedParameters.includes("reasoning_effort") ||
    supportedParameters.includes("include_reasoning") ||
    modelId.includes(":thinking")
  );
}

function pricePerMillion(value: unknown) {
  const numeric = Number(value ?? 0);
  return Number.isFinite(numeric) ? numeric * 1_000_000 : 0;
}
