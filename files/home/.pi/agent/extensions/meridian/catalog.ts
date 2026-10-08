import type { Api, Model, ThinkingLevelMap } from "@earendil-works/pi-ai";
import type { ProviderModelConfig } from "@earendil-works/pi-coding-agent";
import { Type, type Static } from "typebox";
import { Value } from "typebox/value";

export const BASE_URL = "http://127.0.0.1:3456";

export const MODELS_URL = `${BASE_URL}/v1/models`;

const COST = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };

const EFFORTS = ["low", "medium", "high", "xhigh", "max"] as const;

const Support = Type.Object({ supported: Type.Optional(Type.Boolean()) });

const CatalogModel = Type.Object({
	id: Type.String({ pattern: "^[!-~]{1,256}$" }),
	object: Type.Literal("model"),
	owned_by: Type.Literal("anthropic"),
	display_name: Type.String({ pattern: "\\S" }),
	context_window: Type.Integer({ minimum: 1, maximum: Number.MAX_SAFE_INTEGER }),
	capabilities: Type.Object({
		image_input: Type.Optional(Support),
		thinking: Type.Optional(
			Type.Object({
				supported: Type.Optional(Type.Boolean()),
				types: Type.Optional(Type.Object({ adaptive: Type.Optional(Support), enabled: Type.Optional(Support) })),
			}),
		),
		effort: Type.Optional(
			Type.Partial(Type.Object({ low: Support, medium: Support, high: Support, xhigh: Support, max: Support })),
		),
	}),
});

export const Catalog = Type.Object({ object: Type.Literal("list"), data: Type.Array(CatalogModel, { minItems: 1 }) });

export type Catalog = Static<typeof Catalog>;

type CatalogModel = Static<typeof CatalogModel>;

function isAnthropicModel(model: Model<Api>): model is Model<"anthropic-messages"> {
	return model.api === "anthropic-messages";
}

function thinkingMetadata(entry: CatalogModel, known?: Model<"anthropic-messages">) {
	const thinking = entry.capabilities.thinking;
	const reasoning = thinking?.supported ?? known?.reasoning ?? false;
	const adaptive = thinking?.types?.adaptive?.supported;
	const effort = entry.capabilities.effort;
	let thinkingLevelMap: ThinkingLevelMap | undefined = known?.thinkingLevelMap;

	if (reasoning && effort) {
		thinkingLevelMap = { off: thinking?.types?.enabled?.supported === false ? null : known?.thinkingLevelMap?.off };

		for (const level of EFFORTS) thinkingLevelMap[level] = effort[level]?.supported === true ? level : null;
		thinkingLevelMap.minimal = thinkingLevelMap.low;
	}

	const compat: NonNullable<Model<"anthropic-messages">["compat"]> = { ...known?.compat };

	if (adaptive !== undefined) compat.forceAdaptiveThinking = adaptive;

	return { reasoning, thinkingLevelMap, compat };
}

export function buildModels(payload: Catalog, anthropicModels: readonly Model<Api>[]): ProviderModelConfig[] {
	if (!Value.Check(Catalog, payload)) {
		throw new Error("Meridian returned a malformed model catalog");
	}

	const { data } = payload;

	if (new Set(data.map(({ id }) => id)).size !== data.length) throw new Error("Meridian returned duplicate model IDs");
	const builtIn = new Map<string, Model<"anthropic-messages">>();

	for (const model of anthropicModels) if (isAnthropicModel(model)) builtIn.set(model.id, model);

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
				? entry.capabilities.image_input.supported === true
					? ["text", "image"]
					: ["text"]
				: [...(known?.input ?? ["text"])],
			...thinkingMetadata(entry, known),
		};
	});
}

export async function fetchCatalog(signal: AbortSignal, fetcher: typeof fetch = fetch): Promise<Catalog> {
	const response = await fetcher(MODELS_URL, { signal });

	if (!response.ok) throw new Error(`Meridian model discovery failed with HTTP ${response.status}`);

	const catalog = await response.json();

	if (!Value.Check(Catalog, catalog)) throw new Error("Meridian returned a malformed model catalog");

	return catalog;
}

export async function fetchModels(
	anthropicModels: readonly Model<Api>[],
	signal: AbortSignal,
	fetcher: typeof fetch = fetch,
): Promise<ProviderModelConfig[]> {
	return buildModels(await fetchCatalog(signal, fetcher), anthropicModels);
}
