import type { Api, Model, ThinkingLevelMap } from "@earendil-works/pi-ai";
import type { ProviderModelConfig } from "@earendil-works/pi-coding-agent";

export const BASE_URL = "http://127.0.0.1:3456";
export const MODELS_URL = `${BASE_URL}/v1/models`;
const COST = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };
const EFFORTS = ["low", "medium", "high", "xhigh", "max"] as const;
type Support = { supported?: boolean };
type CatalogModel = {
	id: string;
	object: "model";
	owned_by: "anthropic";
	display_name: string;
	context_window: number;
	capabilities: {
		image_input?: Support;
		thinking?: Support & { types?: { adaptive?: Support; enabled?: Support } };
		effort?: Partial<Record<typeof EFFORTS[number], Support>>;
	};
};

function isSupport(value: unknown): boolean {
	return value === undefined || Boolean(value && typeof value === "object" && !Array.isArray(value) &&
		(Reflect.get(value, "supported") === undefined || typeof Reflect.get(value, "supported") === "boolean"));
}

function isCatalogModel(value: unknown): value is CatalogModel {
	if (!value || typeof value !== "object") return false;
	const model = value as Partial<CatalogModel>;
	return typeof model.id === "string" && /^[\x21-\x7e]{1,256}$/.test(model.id) &&
		model.object === "model" && model.owned_by === "anthropic" &&
		typeof model.display_name === "string" && model.display_name.trim().length > 0 &&
		typeof model.context_window === "number" && Number.isSafeInteger(model.context_window) &&
		model.context_window > 0 && Boolean(model.capabilities && typeof model.capabilities === "object" &&
			!Array.isArray(model.capabilities) && isSupport(model.capabilities.image_input) &&
			isSupport(model.capabilities.thinking) && isSupport(model.capabilities.thinking?.types?.adaptive) &&
			isSupport(model.capabilities.thinking?.types?.enabled) && isSupport(model.capabilities.effort) &&
			EFFORTS.every((level) => isSupport(model.capabilities?.effort?.[level])));
}

function thinkingMetadata(entry: CatalogModel, known?: Model<Api>) {
	const thinking = entry.capabilities.thinking;
	const reasoning = thinking?.supported ?? known?.reasoning ?? false;
	const adaptive = thinking?.types?.adaptive?.supported;
	const effort = entry.capabilities.effort;
	let thinkingLevelMap = known?.thinkingLevelMap;
	if (reasoning && effort) {
		thinkingLevelMap = { off: thinking?.types?.enabled?.supported === false ? null : known?.thinkingLevelMap?.off };
		for (const level of EFFORTS) thinkingLevelMap[level] = effort[level]?.supported === true ? level : null;
		thinkingLevelMap.minimal = thinkingLevelMap.low;
	}
	return {
		reasoning,
		thinkingLevelMap: thinkingLevelMap as ThinkingLevelMap | undefined,
		compat: { ...known?.compat, ...(adaptive !== undefined ? { forceAdaptiveThinking: adaptive } : {}) },
	};
}

export function buildModels(payload: unknown, anthropicModels: readonly Model<Api>[]): ProviderModelConfig[] {
	if (!payload || typeof payload !== "object" || Reflect.get(payload, "object") !== "list") {
		throw new Error("Meridian returned a malformed model catalog");
	}
	const data = Reflect.get(payload, "data");
	if (!Array.isArray(data) || data.length === 0 || !data.every(isCatalogModel)) {
		throw new Error("Meridian returned a malformed model catalog");
	}
	if (new Set(data.map(({ id }) => id)).size !== data.length) throw new Error("Meridian returned duplicate model IDs");
	const builtIn = new Map(anthropicModels.map((model) => [model.id, model]));
	return data.map((entry) => {
		const known = builtIn.get(entry.id);
		return {
			...known,
			id: entry.id,
			name: `${entry.display_name} (Meridian)`,
			api: "anthropic-messages",
			baseUrl: BASE_URL,
			cost: known?.cost ?? COST,
			contextWindow: entry.context_window,
			maxTokens: known?.maxTokens ?? entry.context_window,
			input: entry.capabilities.image_input
				? entry.capabilities.image_input.supported === true ? ["text", "image"] : ["text"]
				: [...known?.input ?? ["text"]],
			...thinkingMetadata(entry, known),
		};
	});
}

export async function fetchCatalog(signal: AbortSignal, fetcher: typeof fetch = fetch): Promise<unknown> {
	const response = await fetcher(MODELS_URL, { signal });
	if (!response.ok) throw new Error(`Meridian model discovery failed with HTTP ${response.status}`);
	return response.json();
}

export async function fetchModels(
	anthropicModels: readonly Model<Api>[], signal: AbortSignal, fetcher: typeof fetch = fetch,
): Promise<ProviderModelConfig[]> {
	return buildModels(await fetchCatalog(signal, fetcher), anthropicModels);
}
