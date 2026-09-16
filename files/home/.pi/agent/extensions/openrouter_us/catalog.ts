const MODEL_ID_FIELD = "id";

interface CatalogModel {
	id: string;
	baseUrl?: string;
}

function modelIds(payload: unknown): Set<string> {
	if (!payload || typeof payload !== "object" || !("data" in payload) || !Array.isArray(payload.data)) {
		throw new Error("OpenRouter US model discovery returned an invalid response");
	}

	const ids = payload.data.map((entry) => {
		if (!entry || typeof entry !== "object" || !(MODEL_ID_FIELD in entry) || typeof entry.id !== "string") {
			throw new Error("OpenRouter US model discovery returned a model without an id");
		}
		return entry.id;
	});

	return new Set(ids);
}

export function intersectRegionalModels<T extends CatalogModel>(
	builtInModels: readonly T[],
	payload: unknown,
	baseUrl: string,
): T[] {
	const ids = modelIds(payload);
	const models = builtInModels.filter((model) => ids.has(model.id)).map((model) => ({ ...model, baseUrl }));
	if (models.length === 0) throw new Error("OpenRouter US model discovery matched no built-in models");
	return models;
}

export function restoreRegionalModels<T extends CatalogModel>(
	builtInModels: readonly T[],
	storedModels: readonly CatalogModel[] | undefined,
	baseUrl: string,
): T[] {
	if (!storedModels?.length || storedModels.some((model) => model.baseUrl !== baseUrl)) return [];

	const ids = new Set(storedModels.map((model) => model.id));
	return builtInModels.filter((model) => ids.has(model.id)).map((model) => ({ ...model, baseUrl }));
}
