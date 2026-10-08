import type { Provider, SimpleStreamOptions, StreamOptions } from "@earendil-works/pi-ai";
import { Value } from "typebox/value";
import { RequestPayload } from "./payload.ts";

export const VERCEL_PROVIDER = "vercel-ai-gateway";

export const US_INFERENCE_REGION = {
	scope: "zone",
	geoRegion: "us",
} as const;

export function applyUSInferenceRegion(payload: RequestPayload) {
	const providerOptions = payload.providerOptions ?? {};

	const gateway = providerOptions.gateway ?? {};

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
	// SAFETY: the spread preserves API-specific options; only the shared onPayload callback changes.
	const guardPayload = <T extends StreamOptions | SimpleStreamOptions>(modelId: string, options: T | undefined): T =>
		({
			...options,
			onPayload: async (payload, model) => {
				const result = await options?.onPayload?.(payload, model);
				const finalPayload = result ?? payload;

				if (!Value.Check(RequestPayload, finalPayload) || finalPayload.model !== modelId) {
					throw new Error("Datasafe could not apply Vercel US/no-training controls to the selected model");
				}

				return applyUSInferenceRegion(finalPayload);
			},
		}) as T;

	return {
		...raw,
		stream: (model, context, options) => raw.stream(model, context, guardPayload(model.id, options)),
		streamSimple: (model, context, options) => raw.streamSimple(model, context, guardPayload(model.id, options)),
	};
}
