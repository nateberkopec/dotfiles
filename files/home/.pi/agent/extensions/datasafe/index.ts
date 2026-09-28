import type { Api, Model, Provider } from "@earendil-works/pi-ai";
import { builtinProviders } from "@earendil-works/pi-ai/providers/all";
import { type ExtensionAPI, getAgentDir } from "@earendil-works/pi-coding-agent";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { regionalInferenceBaseUrl } from "./catalog.ts";
import { registerFireworksUS, assertFireworksUSModel } from "./fireworks.ts";
import { preventModelFallback } from "./no_fallback.ts";
import { registerOpenRouterUS, denyOpenRouterCollection } from "./openrouter.ts";
import { profile } from "./profiles.ts";
import { applyUSInferenceRegion, createVercelUSProvider } from "./vercel.ts";

type Strategy = {
	install: (pi: ExtensionAPI, builtins: readonly Provider[]) => void | Promise<void>;
	request: (payload: unknown, model: Model<Api>) => unknown;
};

const strategies: Record<string, Strategy> = {
	openrouter: {
		install: (pi) => registerOpenRouterUS(pi),
		request: (payload, model) => {
			if (model.baseUrl !== regionalInferenceBaseUrl(model, "https://us.openrouter.ai/api/v1")) {
				throw new Error("Datasafe blocked OpenRouter endpoint");
			}
			return denyOpenRouterCollection(payload as Record<string, unknown>);
		},
	},
	fireworks: {
		install: (pi) => registerFireworksUS(pi),
		request: (payload, model) => {
			assertFireworksUSModel((payload as { model?: unknown }).model);
			if (model.baseUrl !== "https://us.api.fireworks.ai/inference/v1") throw new Error("Datasafe blocked Fireworks endpoint");
		},
	},
	"vercel-ai-gateway": {
		install: (pi, builtins) => {
			const provider = builtins.find(({ id }) => id === "vercel-ai-gateway");
			if (!provider) throw new Error("Pi does not provide the built-in Vercel gateway provider");
			pi.registerProvider(createVercelUSProvider(provider));
		},
		request: (payload) => applyUSInferenceRegion(payload as Record<string, unknown>),
	},
};

async function configuredProviderIds(): Promise<string[]> {
	try {
		const config = JSON.parse(await readFile(join(getAgentDir(), "models.json"), "utf8"));
		return Object.keys(config.providers ?? {});
	} catch (error) {
		if (error && typeof error === "object" && "code" in error && error.code === "ENOENT") return [];
		throw error;
	}
}

export default async function datasafe(pi: ExtensionAPI) {
	const allowed = profile.providers === "all" ? undefined : new Set(profile.providers);
	if (allowed) {
		const builtins = builtinProviders();
		for (const provider of builtins) {
			if (!allowed.has(provider.id)) pi.registerProvider(provider.id, { models: [] });
		}
		for (const id of await configuredProviderIds()) {
			if (!allowed.has(id) && !builtins.some((provider) => provider.id === id)) {
				pi.registerProvider(id, { models: [] });
			}
		}
		for (const id of profile.strategies) {
			const strategy = strategies[id];
			if (!strategy) throw new Error(`Unknown datasafe provider strategy: ${id}`);
			await strategy.install(pi, builtins);
		}
	}

	pi.on("before_provider_request", (event, ctx) => {
		if (!allowed) return;
		const model = ctx.model;
		if (!model || !allowed.has(model.provider)) return null;
		return strategies[model.provider] && profile.strategies.includes(model.provider)
			? strategies[model.provider].request(event.payload, model) : undefined;
	});

	pi.on("tool_call", async (event) => {
		if (profile.web === "all" || !event.toolName.startsWith("web_")) return;
		const backend = profile.web[event.toolName];
		if (!backend) return { block: true, reason: `Datasafe blocked web capability: ${event.toolName}` };
		const config = await readFile(join(getAgentDir(), "web-providers.json"), "utf8")
			.then(JSON.parse).catch(() => null);
		if (config?.tools?.[event.toolName.slice(4)] === backend) return;
		return { block: true, reason: `Datasafe requires ${backend} for ${event.toolName}` };
	});

	preventModelFallback(pi);
	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode === "tui" && profile.status) ctx.ui.setStatus("datasafe", profile.status);
	});
}
