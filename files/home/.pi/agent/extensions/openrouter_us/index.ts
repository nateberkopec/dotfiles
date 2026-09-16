import type { Api, Model, RefreshModelsContext } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { intersectRegionalModels, restoreRegionalModels } from "./catalog.ts";

const PROVIDER = "openrouter";
const BASE_URL = "https://us.openrouter.ai/api/v1";
const MODELS_URL = `${BASE_URL}/models`;
const CACHE_TTL_MS = 60 * 60 * 1000;

function cacheIsFresh(checkedAt: number | undefined): boolean {
	return checkedAt !== undefined && Date.now() - checkedAt < CACHE_TTL_MS;
}

async function discoverModels(
	context: RefreshModelsContext,
	builtInModels: readonly Model<Api>[],
): Promise<Model<Api>[]> {
	const cached = restoreRegionalModels(builtInModels, context.stored?.models, BASE_URL);
	if (!context.allowNetwork || (!context.force && cached.length > 0 && cacheIsFresh(context.stored?.checkedAt))) {
		return cached;
	}

	const headers = context.stored?.etag ? { "If-None-Match": context.stored.etag } : undefined;
	const response = await fetch(MODELS_URL, { headers, signal: context.signal });
	if (response.status === 304) {
		if (cached.length === 0) throw new Error("OpenRouter US model discovery returned 304 without a cached catalog");
		await persistModels(context, cached, response.headers.get("etag") ?? context.stored?.etag);
		return cached;
	}
	if (!response.ok) throw new Error(`OpenRouter US model discovery failed with HTTP ${response.status}`);

	const models = intersectRegionalModels(builtInModels, await response.json(), BASE_URL);
	await persistModels(context, models, response.headers.get("etag") ?? undefined);
	return models;
}

async function persistModels(
	context: RefreshModelsContext,
	models: readonly Model<Api>[],
	etag: string | undefined,
): Promise<void> {
	await context.publish({
		persist: { models, checkedAt: Date.now(), ...(etag ? { etag } : {}) },
	});
}

export default function openRouterUS(pi: ExtensionAPI) {
	pi.on("session_start", (_event, context) => {
		const builtInModels = context.modelRegistry.getAll().filter((model) => model.provider === PROVIDER);
		pi.registerProvider(PROVIDER, {
			baseUrl: BASE_URL,
			models: [],
			refreshModels: (refreshContext) => discoverModels(refreshContext, builtInModels),
		});
	});
}
