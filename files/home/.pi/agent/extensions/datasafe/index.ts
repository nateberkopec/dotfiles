import type { Api, Model, Provider } from "@earendil-works/pi-ai";
import { builtinProviders } from "@earendil-works/pi-ai/providers/all";
import { type ExtensionAPI, type ExtensionContext, getAgentDir } from "@earendil-works/pi-coding-agent";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { regionalInferenceBaseUrl } from "./catalog.ts";
import { registerFireworksUS, assertFireworksUSModel } from "./fireworks.ts";
import { registerOpenRouterUS, denyOpenRouterCollection } from "./openrouter.ts";
import { profile } from "./profiles.ts";
import { applyUSInferenceRegion, createVercelUSProvider } from "./vercel.ts";
import { Type } from "typebox";
import { Value } from "typebox/value";
import { RequestPayload } from "./payload.ts";

type Strategy = {
	install: (pi: ExtensionAPI, builtins: readonly Provider[]) => void | Promise<void>;
	request: (payload: RequestPayload, model: Model<Api>) => RequestPayload | undefined;
};

const strategies = {
	openrouter: {
		install: (pi) => registerOpenRouterUS(pi),
		request: (payload, model) => {
			if (model.baseUrl !== regionalInferenceBaseUrl(model, "https://us.openrouter.ai/api/v1")) {
				throw new Error("Datasafe blocked OpenRouter endpoint");
			}

			return denyOpenRouterCollection(payload);
		},
	},
	fireworks: {
		install: (pi) => registerFireworksUS(pi),
		request: (payload, model) => {
			assertFireworksUSModel(payload.model);

			if (model.baseUrl !== "https://us.api.fireworks.ai/inference/v1")
				throw new Error("Datasafe blocked Fireworks endpoint");
		},
	},
	"vercel-ai-gateway": {
		install: (pi, builtins) => {
			const provider = builtins.find(({ id }) => id === "vercel-ai-gateway");

			if (!provider) throw new Error("Pi does not provide the built-in Vercel gateway provider");
			pi.registerProvider(createVercelUSProvider(provider));
		},
		request: (payload) => applyUSInferenceRegion(payload),
	},
} satisfies Record<string, Strategy>;

async function configuredProviderIds(): Promise<string[]> {
	try {
		const config = JSON.parse(await readFile(join(getAgentDir(), "models.json"), "utf8"));

		return Object.keys(config.providers ?? {});
	} catch (error) {
		if (Value.Check(Type.Object({ code: Type.Literal("ENOENT") }), error)) return [];
		throw error;
	}
}

export async function refreshSubagentModels(ctx: ExtensionContext) {
	const providers = profile.strategies.filter((id) => id === "fireworks" || id === "openrouter");

	if (providers.length === 0) return;
	const result = await ctx.modelRegistry.refresh({ providers, allowNetwork: false, signal: ctx.signal });

	if (result.aborted) throw new Error("Datasafe could not refresh the subagent model catalog");

	for (const [provider, error] of result.errors) {
		throw new Error(`Datasafe could not refresh ${provider} before subagent launch`, { cause: error });
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
			const strategy = Object.entries(strategies).find(([name]) => name === id)?.[1];

			if (!strategy) throw new Error(`Unknown datasafe provider strategy: ${id}`);
			await strategy.install(pi, builtins);
		}
	}

	pi.on("before_provider_request", (event, ctx) => {
		if (!allowed) return;
		const model = ctx.model;

		if (!model || !allowed.has(model.provider)) return null;

		const strategy = Object.entries(strategies).find(([name]) => name === model.provider)?.[1];

		if (!strategy || !profile.strategies.includes(model.provider)) return;

		if (!Value.Check(RequestPayload, event.payload)) throw new Error("Datasafe blocked an invalid provider payload");

		return strategy.request(event.payload, model);
	});

	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName === "subagent") await refreshSubagentModels(ctx);
	});

	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode === "tui" && profile.status) ctx.ui.setStatus("datasafe", profile.status);
	});
}
