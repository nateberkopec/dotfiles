import type { Api, Model, Provider, RefreshModelsContext, SimpleStreamOptions, StreamOptions } from "@earendil-works/pi-ai";
import { builtinProviders } from "@earendil-works/pi-ai/providers/all";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { intersectRegionalModels, regionalInferenceBaseUrl, restoreRegionalModels } from "./catalog.ts";

const PROVIDER = "openrouter";
const BASE_URL = "https://us.openrouter.ai/api/v1";
const MODELS_URL = `${BASE_URL}/models`;
const CACHE_TTL_MS = 60 * 60 * 1000;

function cacheIsFresh(checkedAt: number | undefined): boolean {
	return checkedAt !== undefined && Date.now() - checkedAt < CACHE_TTL_MS;
}

async function publishModels(
	context: RefreshModelsContext,
	models: Model<Api>[],
	update: (models: Model<Api>[]) => void,
	persistence?: { checkedAt: number; etag?: string },
): Promise<boolean> {
	return context.publish({
		...(persistence ? { persist: { models, ...persistence } } : {}),
		update: () => update(models),
	});
}

async function refreshModels(
	context: RefreshModelsContext,
	builtInModels: readonly Model<Api>[],
	update: (models: Model<Api>[]) => void,
): Promise<void> {
	const cached = restoreRegionalModels(builtInModels, context.stored?.models, BASE_URL);
	if (cached.length > 0) await publishModels(context, cached, update);
	if (!context.allowNetwork || (!context.force && cached.length > 0 && cacheIsFresh(context.stored?.checkedAt))) return;

	const headers = context.stored?.etag ? { "If-None-Match": context.stored.etag } : undefined;
	const response = await fetch(MODELS_URL, { headers, signal: context.signal });
	if (response.status === 304) {
		if (cached.length === 0) throw new Error("OpenRouter US model discovery returned 304 without a cached catalog");
		const etag = response.headers.get("etag") ?? context.stored?.etag;
		await publishModels(context, cached, update, { checkedAt: Date.now(), ...(etag ? { etag } : {}) });
		return;
	}
	if (!response.ok) throw new Error(`OpenRouter US model discovery failed with HTTP ${response.status}`);

	const models = intersectRegionalModels(builtInModels, await response.json(), BASE_URL);
	const etag = response.headers.get("etag") ?? undefined;
	await publishModels(context, models, update, { checkedAt: Date.now(), ...(etag ? { etag } : {}) });
}

export function createOpenRouterUSProvider(rawProvider: Provider): Provider {
	const builtInModels = rawProvider.getModels();
	let currentModels: Model<Api>[] = [];
	const update = (models: Model<Api>[]) => {
		currentModels = models;
	};
	const guardPayload = <T extends StreamOptions | SimpleStreamOptions>(modelId: string, options: T | undefined): T => ({
		...options,
		onPayload: async (payload, model) => {
			const result = await options?.onPayload?.(payload, model);
			const finalPayload = result ?? payload;
			if (!finalPayload || typeof finalPayload !== "object" || Array.isArray(finalPayload) ||
				(finalPayload as Record<string, unknown>).model !== modelId) {
				throw new Error("Datasafe could not apply OpenRouter no-training controls to the selected model");
			}
			return denyOpenRouterCollection(finalPayload as Record<string, unknown>);
		},
	} as T);
	const assertRegionalModel = (model: Model<Api>) => {
		if (!currentModels.some(({ id }) => id === model.id) || model.baseUrl !== regionalInferenceBaseUrl(model, BASE_URL)) {
			throw new Error(`Datasafe blocked OpenRouter model or endpoint: ${model.id}`);
		}
	};
	return {
		...rawProvider,
		baseUrl: BASE_URL,
		stream: (model, context, options) => {
			assertRegionalModel(model);
			return rawProvider.stream(model, context, guardPayload(model.id, options));
		},
		streamSimple: (model, context, options) => {
			assertRegionalModel(model);
			return rawProvider.streamSimple(model, context, guardPayload(model.id, options));
		},
		getModels: () => currentModels,
		refreshModels: (context) => refreshModels(
			context,
			builtInModels,
			update,
		),
	};
}

export function registerOpenRouterUS(pi: ExtensionAPI) {
	const rawProvider = builtinProviders().find((provider) => provider.id === PROVIDER);
	if (!rawProvider) throw new Error("Pi does not provide the built-in OpenRouter provider");
	pi.registerProvider(createOpenRouterUSProvider(rawProvider));
}

export function denyOpenRouterCollection(payload: Record<string, unknown>): Record<string, unknown> {
	const provider = payload.provider;
	return {
		...payload,
		provider: {
			...(provider && typeof provider === "object" ? provider : {}),
			data_collection: "deny",
		},
	};
}
