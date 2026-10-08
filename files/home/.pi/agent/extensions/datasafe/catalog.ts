import { Type, type Static } from "typebox";
import { Value } from "typebox/value";

export const RegionalCatalog = Type.Object({ data: Type.Array(Type.Object({ id: Type.String() })) });

export type RegionalCatalog = Static<typeof RegionalCatalog>;

interface CatalogModel {
	id: string;
	api?: string;
	baseUrl?: string;
}

export function regionalInferenceBaseUrl(model: CatalogModel, catalogBaseUrl: string): string {
	return model.api === "anthropic-messages" ? catalogBaseUrl.replace(/\/v1$/, "") : catalogBaseUrl;
}

function modelIds(payload: RegionalCatalog): Set<string> {
	if (!Value.Check(Type.Object({ data: Type.Array(Type.Unknown()) }), payload)) {
		throw new Error("OpenRouter US model discovery returned an invalid response");
	}

	if (!Value.Check(RegionalCatalog, payload))
		throw new Error("OpenRouter US model discovery returned a model without an id");

	return new Set(payload.data.map((entry) => entry.id));
}

export function intersectRegionalModels<T extends CatalogModel>(
	builtInModels: readonly T[],
	payload: RegionalCatalog,
	baseUrl: string,
): T[] {
	const ids = modelIds(payload);

	const models = builtInModels.flatMap((model) =>
		ids.has(model.id) ? [{ ...model, baseUrl: regionalInferenceBaseUrl(model, baseUrl) }] : [],
	);

	if (models.length === 0) throw new Error("OpenRouter US model discovery matched no built-in models");

	return models;
}

export function restoreRegionalModels<T extends CatalogModel>(
	builtInModels: readonly T[],
	storedModels: readonly CatalogModel[] | undefined,
	baseUrl: string,
): T[] {
	if (
		!storedModels?.length ||
		storedModels.some(
			(model) => model.baseUrl !== baseUrl && model.baseUrl !== regionalInferenceBaseUrl(model, baseUrl),
		)
	)
		return [];

	const ids = new Set(storedModels.map((model) => model.id));

	return builtInModels.flatMap((model) =>
		ids.has(model.id) ? [{ ...model, baseUrl: regionalInferenceBaseUrl(model, baseUrl) }] : [],
	);
}
