import { builtinProviders } from "@earendil-works/pi-ai/providers/all";
import type { RefreshModelsContext } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ProviderModelConfig } from "@earendil-works/pi-coding-agent";
import { BASE_URL, buildModels, fetchCatalog } from "./meridian/catalog.ts";
import { readCatalogCache, writeCatalogCache } from "./meridian/cache.ts";
import { header, requestOptions, setHeader, type RequestState } from "./meridian/requests.ts";

export { buildModels, fetchModels } from "./meridian/catalog.ts";

const PROVIDER = "meridian";

export default async function meridian(pi: ExtensionAPI) {
	const state: RequestState = { child: process.env.PI_SUBAGENT_CHILD === "1" };
	pi.on("session_start", (_event, ctx) => {
		state.sessionId = ctx.sessionManager.getSessionId();
		state.compacting = false;
	});
	pi.on("session_before_compact", () => {
		state.compacting = true;
	});
	pi.on("session_compact", () => {
		state.compacting = false;
	});
	pi.on("session_compact_failed", () => {
		state.compacting = false;
	});
	// Resolve conversation identity per request so session switches and forks stay isolated.
	pi.on("before_provider_headers", (event, ctx) => {
		if (header(event.headers, "x-meridian-agent") !== "pi") return;
		state.sessionId = ctx.sessionManager.getSessionId();

		if (header(event.headers, "x-session-affinity")) return;
		setHeader(event.headers, "x-session-affinity", state.sessionId);
	});

	const anthropic = builtinProviders().find((provider) => provider.id === "anthropic");

	if (!anthropic) throw new Error("Pi does not provide the built-in Anthropic provider");
	const anthropicModels = anthropic.getModels();
	let models: ProviderModelConfig[] = readCatalogCache(anthropicModels);

	const discover = async (signal: AbortSignal) => {
		const catalog = await fetchCatalog(signal);
		const discovered = buildModels(catalog, anthropicModels);
		signal.throwIfAborted();
		writeCatalogCache(catalog);
		models = discovered;

		return models;
	};

	try {
		await discover(AbortSignal.timeout(2_000));
	} catch (error) {
		console.error(
			`[meridian] ${error instanceof Error ? error.message : String(error)}. ${models.length ? "Using the cached Meridian catalog. " : ""}Start Meridian at ${BASE_URL}, then open /model to retry discovery.`,
		);
	}

	const refreshModels = async (context: RefreshModelsContext) => {
		if (!context.allowNetwork) return models;

		return discover(AbortSignal.any([context.signal, AbortSignal.timeout(3_000)]));
	};

	pi.registerProvider(PROVIDER, {
		name: "Meridian (Claude Max)",
		baseUrl: BASE_URL,
		apiKey: "x",
		api: "anthropic-messages",
		headers: { "x-meridian-agent": "pi" },
		models,
		refreshModels,
		// Delegate all protocol, thinking, streaming, tool and usage behavior to Pi's built-in API.
		streamSimple: (model, context, options) =>
			anthropic.streamSimple(model, context, requestOptions(context, options, state)),
	});
}
