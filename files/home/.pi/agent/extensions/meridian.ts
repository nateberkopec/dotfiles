import { builtinProviders } from "@earendil-works/pi-ai/providers/all";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const PROVIDER = "meridian";
const BASE_URL = "http://127.0.0.1:3456";
const SUPPORTED_MODELS = new Set([
	"claude-fable-5",
	"claude-opus-5",
	"claude-opus-4-8",
	"claude-opus-4-7",
	"claude-sonnet-4-6",
	"claude-opus-4-6",
	"claude-haiku-4-5-20251001",
]);

export default function meridian(pi: ExtensionAPI) {
	const anthropic = builtinProviders().find((provider) => provider.id === "anthropic");
	if (!anthropic) throw new Error("Pi does not provide the built-in Anthropic provider");

	const models = anthropic.getModels().filter((model) => SUPPORTED_MODELS.has(model.id));
	if (models.length !== SUPPORTED_MODELS.size) {
		throw new Error("Pi's Anthropic catalog is missing a Meridian-supported model");
	}

	pi.registerProvider(PROVIDER, {
		name: "Meridian (Claude Max)",
		baseUrl: BASE_URL,
		apiKey: "x",
		api: "anthropic-messages",
		headers: { "x-meridian-agent": "pi" },
		models: models.map((model) => ({
			...model,
			provider: PROVIDER,
			baseUrl: BASE_URL,
			api: "anthropic-messages",
			name: `${model.name} (Meridian)`,
		})),
	});
}
