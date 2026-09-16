import type { Api, Model } from "@earendil-works/pi-ai";

export const FIREWORKS_PROVIDER = "fireworks";
export const FIREWORKS_BASE_URL = "https://us.api.fireworks.ai/inference/v1";
export const FIREWORKS_US_DOCS_URL = "https://docs.fireworks.ai/serverless/us-only-serverless.md";
const FIREWORKS_MODELS_URL = `${FIREWORKS_BASE_URL}/models`;
const US_MODEL_ID = /^accounts\/fireworks\/(?:models|routers)\/[a-z0-9][a-z0-9._-]*-us$/;

type FireworksModel = Model<"openai-completions">;
type CatalogEntry = { id: string; name: string };
type ApiModel = {
	id?: unknown;
	context_length?: unknown;
	supports_chat?: unknown;
	supports_image_input?: unknown;
};

export function parseUSModelCatalog(markdown: string): CatalogEntry[] {
	const heading = markdown.match(/^## Available models\s*$/m);
	if (heading?.index === undefined) {
		throw new Error("Fireworks US-only documentation has no Available models section");
	}
	const section = markdown.slice(heading.index + heading[0].length).split(/^##\s/m, 1)[0];

	const entries = [...section.matchAll(/^\|\s*([^|]+?)\s*\|\s*`([^`]+)`\s*\|\s*$/gm)]
		.map((match) => ({ name: match[1].trim(), id: match[2].trim() }));
	if (entries.length === 0) throw new Error("Fireworks US-only model table is empty or malformed");
	if (entries.some(({ id }) => !US_MODEL_ID.test(id))) {
		throw new Error("Fireworks US-only model table contains an unsafe model ID");
	}
	if (new Set(entries.map(({ id }) => id)).size !== entries.length) {
		throw new Error("Fireworks US-only model table contains duplicate model IDs");
	}
	return entries;
}

function metadataIdCandidates(usId: string): string[] {
	const baseId = usId.replace(/-us$/, "");
	const alternateKind = baseId.includes("/routers/")
		? baseId.replace("/routers/", "/models/")
		: baseId.replace("/models/", "/routers/");
	return [baseId, alternateKind];
}

export function buildUSModels(entries: CatalogEntry[], apiModels: ApiModel[]): FireworksModel[] {
	const metadata = new Map(apiModels
		.filter((model): model is ApiModel & { id: string } => typeof model.id === "string")
		.map((model) => [model.id, model]));

	return entries.map(({ id, name }) => {
		const details = metadataIdCandidates(id).map((candidate) => metadata.get(candidate)).find(Boolean);
		if (!details || details.supports_chat !== true ||
			typeof details.context_length !== "number" || details.context_length <= 0) {
			throw new Error(`Fireworks returned no usable chat metadata for US-only model: ${id}`);
		}
		return {
			id,
			name: `${name} (Fireworks US-only)`,
			api: "openai-completions",
			provider: FIREWORKS_PROVIDER,
			baseUrl: FIREWORKS_BASE_URL,
			reasoning: true,
			input: details.supports_image_input === true ? ["text", "image"] : ["text"],
			cost: { input: 0, cacheRead: 0, cacheWrite: 0, output: 0 },
			contextWindow: details.context_length,
			maxTokens: Math.min(details.context_length, 131_072),
			compat: {
				supportsStore: false,
				supportsDeveloperRole: false,
				sendSessionAffinityHeaders: true,
				supportsLongCacheRetention: false,
			},
		};
	});
}

export async function fetchUSModels(
	apiKey: string,
	signal: AbortSignal,
	fetcher: typeof fetch = fetch,
): Promise<FireworksModel[]> {
	const [docsResponse, modelsResponse] = await Promise.all([
		fetcher(FIREWORKS_US_DOCS_URL, { signal }),
		fetcher(FIREWORKS_MODELS_URL, {
			signal,
			headers: { Authorization: `Bearer ${apiKey}` },
		}),
	]);
	if (!docsResponse.ok) throw new Error(`Fireworks US-only documentation returned HTTP ${docsResponse.status}`);
	if (!modelsResponse.ok) throw new Error(`Fireworks models API returned HTTP ${modelsResponse.status}`);

	const payload = await modelsResponse.json() as { data?: unknown };
	if (!Array.isArray(payload.data)) throw new Error("Fireworks models API returned a malformed catalog");
	return buildUSModels(parseUSModelCatalog(await docsResponse.text()), payload.data as ApiModel[]);
}

export function isUSModelId(id: unknown): id is string {
	return typeof id === "string" && US_MODEL_ID.test(id);
}

export class USModelCatalog {
	#models: FireworksModel[] = [];
	#allowedIds = new Set<string>();

	getModels(): readonly FireworksModel[] {
		return this.#models;
	}

	replace(nextModels: readonly Model<Api>[]) {
		if (nextModels.some((model) =>
			model.provider !== FIREWORKS_PROVIDER || model.api !== "openai-completions" ||
			model.baseUrl !== FIREWORKS_BASE_URL || !isUSModelId(model.id))) {
			throw new Error("Refusing invalid cached Fireworks US-only catalog");
		}
		this.#models = nextModels as FireworksModel[];
		this.#allowedIds = new Set(nextModels.map(({ id }) => id));
	}

	assertAllowed(model: unknown): asserts model is string {
		if (typeof model !== "string" || !this.#allowedIds.has(model)) {
			throw new Error(`Blocked model outside current Fireworks US-only catalog: ${String(model)}`);
		}
	}
}
