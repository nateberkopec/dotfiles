import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const FIREWORKS_PROVIDER = "fireworks";

type FireworksAlias = {
	targetModel: string;
	serviceTier?: "priority";
};

type ProviderPayload = {
	model?: unknown;
	service_tier?: unknown;
	[key: string]: unknown;
};

const MODEL_ALIASES: Record<string, FireworksAlias> = {
	"kimi-k2p6": {
		targetModel: "accounts/fireworks/models/kimi-k2p6",
	},
	"kimi-k2p6-priority": {
		targetModel: "accounts/fireworks/models/kimi-k2p6",
		serviceTier: "priority",
	},
	"kimi-k2p6-fast": {
		targetModel: "accounts/fireworks/routers/kimi-k2p6-fast",
	},
	"glm-5p2": {
		targetModel: "accounts/fireworks/models/glm-5p2",
	},
	"glm-5p2-priority": {
		targetModel: "accounts/fireworks/models/glm-5p2",
		serviceTier: "priority",
	},
};

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

function rewrittenPayload(payload: ProviderPayload, alias: FireworksAlias) {
	const { service_tier: _serviceTier, ...rest } = payload;

	return {
		...rest,
		model: alias.targetModel,
		...(alias.serviceTier ? { service_tier: alias.serviceTier } : {}),
	};
}

export default function (pi: ExtensionAPI) {
	pi.on("before_provider_request", (event, ctx) => {
		if (ctx.model?.provider !== FIREWORKS_PROVIDER) return;
		if (!isRecord(event.payload)) return;

		const payload = event.payload as ProviderPayload;
		if (typeof payload.model !== "string") return;

		const alias = MODEL_ALIASES[payload.model];
		if (!alias) return;

		return rewrittenPayload(payload, alias);
	});
}
