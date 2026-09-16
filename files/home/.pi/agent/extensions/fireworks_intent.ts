import { openAICompletionsApi } from "@earendil-works/pi-ai/api/openai-completions.lazy";
import {
	envApiKeyAuth,
	type Api,
	type Context,
	type Model,
	type Provider,
	type RefreshModelsContext,
	type SimpleStreamOptions,
	type StreamOptions,
} from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	fetchUSModels,
	FIREWORKS_BASE_URL,
	FIREWORKS_PROVIDER,
	USModelCatalog,
} from "./fireworks_catalog.ts";

const fireworksApi = openAICompletionsApi();
const catalog: USModelCatalog = new USModelCatalog();

async function refreshModels(context: RefreshModelsContext) {
	if (context.stored) {
		const restored = context.stored.models.filter(({ provider }) => provider === FIREWORKS_PROVIDER);
		if (!(await context.publish({ update: () => catalog.replace(restored) }))) return;
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

const guardedApi = {
	stream(model: Model<Api>, context: Context, options?: StreamOptions) {
		catalog.assertAllowed(model.id);
		return fireworksApi.stream(model, context, options);
	},
	streamSimple(model: Model<Api>, context: Context, options?: SimpleStreamOptions) {
		catalog.assertAllowed(model.id);
		return fireworksApi.streamSimple(model, context, options);
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

export default function (pi: ExtensionAPI) {
	pi.registerProvider(provider);
	pi.on("before_provider_request", (event, ctx) => {
		if (ctx.model?.provider !== FIREWORKS_PROVIDER) return;
		catalog.assertAllowed((event.payload as { model?: unknown }).model);
	});
}
