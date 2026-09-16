import type { Api, Model, Provider, RefreshModelsContext } from "@earendil-works/pi-ai";
import { builtinProviders } from "@earendil-works/pi-ai/providers/all";
import { type ExtensionAPI, getAgentDir } from "@earendil-works/pi-coding-agent";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { intersectRegionalModels, restoreRegionalModels } from "./catalog.ts";

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

interface Discovery {
	models: Model<Api>[];
	checkedAt: number;
	etag?: string;
}

interface StoredCatalog {
	models: Array<{ id: string; baseUrl?: string }>;
	checkedAt?: number;
	etag?: string;
}

async function discoverModels(
	builtInModels: readonly Model<Api>[],
	cached: Model<Api>[],
	etag: string | undefined,
	signal?: AbortSignal,
): Promise<Discovery> {
	const headers = cached.length > 0 && etag ? { "If-None-Match": etag } : undefined;
	const response = await fetch(MODELS_URL, { headers, signal });
	if (response.status === 304) {
		if (cached.length === 0) throw new Error("OpenRouter US model discovery returned 304 without a cached catalog");
		return { models: cached, checkedAt: Date.now(), etag };
	}
	if (!response.ok) throw new Error(`OpenRouter US model discovery failed with HTTP ${response.status}`);
	const models = intersectRegionalModels(builtInModels, await response.json(), BASE_URL);
	const responseEtag = response.headers.get("etag") ?? undefined;
	return { models, checkedAt: Date.now(), ...(responseEtag ? { etag: responseEtag } : {}) };
}

function isStoredModel(value: unknown): value is { id: string; baseUrl?: string } {
	return Boolean(
		value &&
		typeof value === "object" &&
		"id" in value &&
		typeof value.id === "string" &&
		(!("baseUrl" in value) || typeof value.baseUrl === "string"),
	);
}

function parseStoredCatalog(payload: unknown): StoredCatalog | undefined {
	if (!payload || typeof payload !== "object") return;
	const stored = Reflect.get(payload, PROVIDER);
	if (!stored || typeof stored !== "object" || !("models" in stored) || !Array.isArray(stored.models)) return;
	if (!stored.models.every(isStoredModel)) return;
	const checkedAt = "checkedAt" in stored && typeof stored.checkedAt === "number" ? stored.checkedAt : undefined;
	const etag = "etag" in stored && typeof stored.etag === "string" ? stored.etag : undefined;
	return { models: stored.models, ...(checkedAt !== undefined ? { checkedAt } : {}), ...(etag ? { etag } : {}) };
}

async function readStoredCatalog(): Promise<StoredCatalog | undefined> {
	try {
		return parseStoredCatalog(JSON.parse(await readFile(join(getAgentDir(), "models-store.json"), "utf8")));
	} catch (error) {
		if (error && typeof error === "object" && "code" in error && error.code === "ENOENT") return;
		throw error;
	}
}

async function loadInitialDiscovery(builtInModels: readonly Model<Api>[]): Promise<Discovery | undefined> {
	const stored = await readStoredCatalog();
	const cached = restoreRegionalModels(builtInModels, stored?.models, BASE_URL);
	const checkedAt = stored?.checkedAt;
	if (cached.length > 0 && checkedAt !== undefined && cacheIsFresh(checkedAt)) {
		return { models: cached, checkedAt, ...(stored?.etag ? { etag: stored.etag } : {}) };
	}
	if (process.env.PI_OFFLINE !== undefined) return;
	return discoverModels(builtInModels, cached, stored?.etag, AbortSignal.timeout(15_000));
}

async function refreshModels(
	context: RefreshModelsContext,
	builtInModels: readonly Model<Api>[],
	update: (models: Model<Api>[]) => void,
	initialDiscovery: () => Discovery | undefined,
	clearInitialDiscovery: () => void,
): Promise<void> {
	const initial = initialDiscovery();
	if (initial) {
		if (await publishModels(context, initial.models, update, initial)) clearInitialDiscovery();
		return;
	}

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

export function createOpenRouterUSProvider(rawProvider: Provider, discovered?: Discovery): Provider {
	const builtInModels = rawProvider.getModels();
	let currentModels = discovered?.models ?? [];
	let pendingDiscovery = discovered;
	const update = (models: Model<Api>[]) => {
		currentModels = models;
	};
	return {
		...rawProvider,
		baseUrl: BASE_URL,
		getModels: () => currentModels,
		refreshModels: (context) => refreshModels(
			context,
			builtInModels,
			update,
			() => pendingDiscovery,
			() => { pendingDiscovery = undefined; },
		),
	};
}

export default async function openRouterUS(pi: ExtensionAPI) {
	const rawProvider = builtinProviders().find((provider) => provider.id === PROVIDER);
	if (!rawProvider) throw new Error("Pi does not provide the built-in OpenRouter provider");

	let discovered: Discovery | undefined;
	try {
		discovered = await loadInitialDiscovery(rawProvider.getModels());
	} catch (error) {
		console.error(`[openrouter_us] ${error instanceof Error ? error.message : String(error)}`);
	}
	pi.registerProvider(createOpenRouterUSProvider(rawProvider, discovered));
}
