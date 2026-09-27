import type { Provider, SimpleStreamOptions, StreamOptions } from "@earendil-works/pi-ai";

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
				disallowPromptTraining: true,
			},
		},
	};
}

export function createVercelUSProvider(raw: Provider): Provider {
	const guardPayload = <T extends StreamOptions | SimpleStreamOptions>(modelId: string, options: T | undefined): T => ({
		...options,
		onPayload: async (payload, model) => {
			const result = await options?.onPayload?.(payload, model);
			const finalPayload = result ?? payload;
			if (!finalPayload || typeof finalPayload !== "object" || Array.isArray(finalPayload) ||
				(finalPayload as Record<string, unknown>).model !== modelId) {
				throw new Error("Datasafe could not apply Vercel US/no-training controls to the selected model");
			}
			return applyUSInferenceRegion(finalPayload as Record<string, unknown>);
		},
	} as T);
	return {
		...raw,
		stream: (model, context, options) => raw.stream(model, context, guardPayload(model.id, options)),
		streamSimple: (model, context, options) => raw.streamSimple(model, context, guardPayload(model.id, options)),
	};
}
