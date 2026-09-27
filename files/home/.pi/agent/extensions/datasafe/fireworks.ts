import {
	envApiKeyAuth,
	type Api,
	type TranscriptContext,
	type Model,
	type Provider,
	type RefreshModelsContext,
	type SimpleStreamOptions,
	type StreamOptions,
} from "@earendil-works/pi-ai";
import { builtinProviders } from "@earendil-works/pi-ai/providers/all";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	cachedUSModels,
	fetchUSModels,
	FIREWORKS_BASE_URL,
	FIREWORKS_PROVIDER,
	USModelCatalog,
} from "./fireworks_catalog.ts";

const fireworksApi = builtinProviders().find((provider) => provider.id === FIREWORKS_PROVIDER);
if (!fireworksApi) throw new Error("Pi does not provide the built-in Fireworks provider");
const catalog: USModelCatalog = new USModelCatalog();

async function refreshModels(context: RefreshModelsContext) {
	if (catalog.getModels().length > 0 && !context.allowNetwork) {
		await context.publish({
			persist: { models: [...catalog.getModels()], checkedAt: Date.now() },
			update: () => {},
		});
		return;
	}
	if (context.stored && catalog.getModels().length === 0) {
		const restored = cachedUSModels(context.stored.models);
		if (restored.length > 0 && !(await context.publish({ update: () => catalog.replace(restored) }))) return;
	}
	if (!context.allowNetwork || context.signal.aborted) return;
	const apiKey = context.credential?.type === "api_key" ? context.credential.key : undefined;
	if (!apiKey) throw new Error("Fireworks model discovery requires an API key");

	const refreshed = await fetchUSModels(apiKey, context.signal);
	if (context.signal.aborted) return;
	await context.publish({
		persist: { models: refreshed, checkedAt: Date.now() },
		update: () => catalog.replace(refreshed),
	});
}

function guardPayload<T extends StreamOptions | SimpleStreamOptions>(modelId: string, options: T | undefined): T {
	return {
		...options,
		onPayload: async (payload, model) => {
			const result = await options?.onPayload?.(payload, model);
			const finalPayload = result ?? payload;
			if (!finalPayload || typeof finalPayload !== "object" || Array.isArray(finalPayload) ||
				(finalPayload as Record<string, unknown>).model !== modelId) {
				throw new Error("Datasafe blocked Fireworks payload model substitution");
			}
			catalog.assertAllowed(modelId);
			return finalPayload;
		},
	} as T;
}

const guardedApi = {
	stream(model: Model<Api>, context: TranscriptContext, options?: StreamOptions) {
		catalog.assertAllowed(model.id);
		return fireworksApi.stream(model, context, guardPayload(model.id, options));
	},
	streamSimple(model: Model<Api>, context: TranscriptContext, options?: SimpleStreamOptions) {
		catalog.assertAllowed(model.id);
		return fireworksApi.streamSimple(model, context, guardPayload(model.id, options));
	},
};

const provider: Provider<"openai-completions"> = {
	id: FIREWORKS_PROVIDER,
	name: "Fireworks US-only",
	baseUrl: FIREWORKS_BASE_URL,
	auth: { apiKey: envApiKeyAuth("Fireworks API key", ["FIREWORKS_API_KEY"]) },
	getModels: () => catalog.getModels(),
	refreshModels,
	stream: guardedApi.stream,
	streamSimple: guardedApi.streamSimple,
};

export async function registerFireworksUS(pi: ExtensionAPI) {
	const apiKey = process.env.FIREWORKS_API_KEY;
	if (process.env.PI_OFFLINE === undefined && apiKey) {
		try {
			catalog.replace(await fetchUSModels(apiKey, AbortSignal.timeout(15_000)));
		} catch (error) {
			console.warn(`Fireworks model discovery failed; using the cached catalog: ${String(error)}`);
		}
	}

	pi.registerProvider(provider);
}

export function assertFireworksUSModel(model: unknown): void {
	catalog.assertAllowed(model);
}
