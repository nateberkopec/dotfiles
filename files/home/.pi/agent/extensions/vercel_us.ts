import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export const VERCEL_PROVIDER = "vercel-ai-gateway";
export const US_INFERENCE_REGION = {
	scope: "zone",
	geoRegion: "us",
} as const;

export function applyUSInferenceRegion<T extends Record<string, unknown>>(payload: T): T {
	const providerOptions = (payload.providerOptions && typeof payload.providerOptions === "object")
		? payload.providerOptions as Record<string, unknown>
		: {};

	const gateway = (providerOptions.gateway && typeof providerOptions.gateway === "object")
		? providerOptions.gateway as Record<string, unknown>
		: {};

	return {
		...payload,
		providerOptions: {
			...providerOptions,
			gateway: {
				...gateway,
				inferenceRegion: US_INFERENCE_REGION,
			},
		},
	};
}

export default function vercelUS(pi: ExtensionAPI) {
	pi.on("before_provider_request", (event, ctx) => {
		if (ctx.model?.provider !== VERCEL_PROVIDER) return;
		return applyUSInferenceRegion(event.payload as Record<string, unknown>);
	});
}
