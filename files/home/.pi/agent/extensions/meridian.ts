import type { Api, Model, RefreshModelsContext } from "@earendil-works/pi-ai";
import { builtinProviders } from "@earendil-works/pi-ai/providers/all";
import type { ExtensionAPI, ProviderModelConfig } from "@earendil-works/pi-coding-agent";

const PROVIDER = "meridian";
const BASE_URL = "http://127.0.0.1:3456";
const MODELS_URL = `${BASE_URL}/v1/models`;
const COST = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };

type CatalogModel = {
	id: string;
	object: "model";
	owned_by: "anthropic";
	display_name: string;
	context_window: number;
	capabilities: {
		image_input?: { supported?: boolean };
		thinking?: { supported?: boolean };
	};
};

function isCatalogModel(value: unknown): value is CatalogModel {
	if (!value || typeof value !== "object") return false;
	const model = value as Partial<CatalogModel>;
	return typeof model.id === "string" && model.id.length > 0 &&
		model.object === "model" && model.owned_by === "anthropic" &&
		typeof model.display_name === "string" && model.display_name.length > 0 &&
		typeof model.context_window === "number" && Number.isInteger(model.context_window) &&
		model.context_window > 0 && Boolean(model.capabilities && typeof model.capabilities === "object");
}

export function buildModels(payload: unknown, anthropicModels: readonly Model<Api>[]): ProviderModelConfig[] {
	if (!payload || typeof payload !== "object" || Reflect.get(payload, "object") !== "list") {
		throw new Error("Meridian returned a malformed model catalog");
	}
	const data = Reflect.get(payload, "data");
	if (!Array.isArray(data) || data.length === 0 || !data.every(isCatalogModel)) {
		throw new Error("Meridian returned a malformed model catalog");
	}
	const ids = new Set(data.map(({ id }) => id));
	if (ids.size !== data.length) throw new Error("Meridian returned duplicate model IDs");

	const builtIn = new Map(anthropicModels.map((model) => [model.id, model]));
	return data.map((entry) => {
		const known = builtIn.get(entry.id);
		const metadata = known ?? {
			id: entry.id,
			name: entry.display_name,
			reasoning: entry.capabilities.thinking?.supported === true,
			input: entry.capabilities.image_input?.supported === true ? ["text", "image"] as const : ["text"] as const,
			cost: COST,
			contextWindow: entry.context_window,
			maxTokens: entry.context_window,
		};
		return {
			...metadata,
			id: entry.id,
			name: `${entry.display_name} (Meridian)`,
			api: "anthropic-messages",
			baseUrl: BASE_URL,
			input: [...metadata.input],
		};
	});
}

export async function fetchModels(
	anthropicModels: readonly Model<Api>[],
	signal: AbortSignal,
	fetcher: typeof fetch = fetch,
): Promise<ProviderModelConfig[]> {
	const response = await fetcher(MODELS_URL, { signal });
	if (!response.ok) throw new Error(`Meridian model discovery failed with HTTP ${response.status}`);
	return buildModels(await response.json(), anthropicModels);
}

export default async function meridian(pi: ExtensionAPI) {
	const anthropic = builtinProviders().find((provider) => provider.id === "anthropic");
	if (!anthropic) throw new Error("Pi does not provide the built-in Anthropic provider");

	const anthropicModels = anthropic.getModels();
	let models: ProviderModelConfig[] = [];
	try {
		models = await fetchModels(anthropicModels, AbortSignal.timeout(2_000));
	} catch (error) {
		console.error(`[meridian] ${error instanceof Error ? error.message : String(error)}. Start Meridian at ${BASE_URL}, then open /model to retry discovery.`);
	}

	const refreshModels = async (context: RefreshModelsContext) => {
		if (!context.allowNetwork) return models;
		models = await fetchModels(anthropicModels, context.signal);
		return models;
	};

	pi.registerProvider(PROVIDER, {
		name: "Meridian (Claude Max)",
		baseUrl: BASE_URL,
		apiKey: "x",
		api: "anthropic-messages",
		headers: { "x-meridian-agent": "pi" },
		models,
		refreshModels,
	});
}
