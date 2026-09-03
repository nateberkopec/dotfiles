import {
	createProvider,
	envApiKeyAuth,
	openAICompletionsApi,
	type Api,
	type Context,
	type Model,
	type SimpleStreamOptions,
	type StreamOptions,
} from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const FIREWORKS_PROVIDER = "fireworks";
const FIREWORKS_BASE_URL = "https://us.api.fireworks.ai/inference/v1";
const KIMI_K3_US = "accounts/fireworks/routers/kimi-k3-us";
const GLM_5P2_FAST_US = "accounts/fireworks/routers/glm-5p2-fast-us";
const US_ONLY_MODELS = new Set([KIMI_K3_US, GLM_5P2_FAST_US]);

function assertUSOnlyModel(model: unknown): asserts model is string {
	if (typeof model !== "string" || !US_ONLY_MODELS.has(model)) {
		throw new Error(`Blocked non-US Fireworks model: ${String(model)}`);
	}
}

const fireworksApi = openAICompletionsApi();
const guardedApi = {
	stream(model: Model<Api>, context: Context, options?: StreamOptions) {
		assertUSOnlyModel(model.id);
		return fireworksApi.stream(model, context, options);
	},
	streamSimple(model: Model<Api>, context: Context, options?: SimpleStreamOptions) {
		assertUSOnlyModel(model.id);
		return fireworksApi.streamSimple(model, context, options);
	},
};

const models = [
	{
		id: KIMI_K3_US,
		name: "Kimi K3 (Fireworks US-only)",
		api: "openai-completions" as const,
		provider: FIREWORKS_PROVIDER,
		baseUrl: FIREWORKS_BASE_URL,
		reasoning: true,
		input: ["text", "image"] as const,
		cost: {
			input: 3.3,
			cacheRead: 0.33,
			cacheWrite: 0,
			output: 16.5,
		},
		contextWindow: 1_048_576,
		maxTokens: 131_072,
		compat: {
			supportsStore: false,
			supportsDeveloperRole: false,
			sendSessionAffinityHeaders: true,
			supportsLongCacheRetention: false,
			requiresReasoningContentOnAssistantMessages: true,
			thinkingFormat: "openai" as const,
			deferredToolsMode: "kimi" as const,
		},
	},
	{
		id: GLM_5P2_FAST_US,
		name: "GLM 5.2 Fast (Fireworks US-only)",
		api: "openai-completions" as const,
		provider: FIREWORKS_PROVIDER,
		baseUrl: FIREWORKS_BASE_URL,
		reasoning: true,
		input: ["text"] as const,
		cost: {
			input: 2.1,
			cacheRead: 0.21,
			cacheWrite: 0,
			output: 6.6,
		},
		contextWindow: 1_048_575,
		maxTokens: 131_072,
		compat: {
			supportsStore: false,
			supportsDeveloperRole: false,
			sendSessionAffinityHeaders: true,
			supportsLongCacheRetention: false,
		},
	},
];

export default function (pi: ExtensionAPI) {
	pi.registerProvider(createProvider({
		id: FIREWORKS_PROVIDER,
		name: "Fireworks US-only",
		baseUrl: FIREWORKS_BASE_URL,
		auth: {
			apiKey: envApiKeyAuth("Fireworks API key", ["FIREWORKS_API_KEY"]),
		},
		models,
		api: guardedApi,
	}));

	pi.on("before_provider_request", (event, ctx) => {
		if (ctx.model?.provider !== FIREWORKS_PROVIDER) return;
		const payload = event.payload as { model?: unknown };
		assertUSOnlyModel(payload.model);
	});
}
