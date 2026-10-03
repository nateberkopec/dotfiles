import type { Provider } from "@earendil-works/pi-ai";
import { type ExtensionAPI, type ExtensionContext, getAgentDir } from "@earendil-works/pi-coding-agent";
import { readFile } from "node:fs/promises";
import { join } from "node:path";

type Defaults = { defaultProvider?: string; defaultModel?: string };
type Fallback = { error: string; canSelectModel: boolean };

async function settings(path: string): Promise<Defaults> {
	try {
		return JSON.parse(await readFile(path, "utf8")) as Defaults;
	} catch (error) {
		if (error && typeof error === "object" && "code" in error && error.code === "ENOENT") return {};
		throw error;
	}
}

function explicitCliModel(): boolean {
	return process.argv.slice(2).some((arg) => ["--model", "--models"].includes(arg));
}

async function fallbackError(ctx: ExtensionContext): Promise<Fallback | undefined> {
	const selected = ctx.model;
	if (!selected || explicitCliModel()) return;
	const branch = ctx.sessionManager.getBranch();
	const changes = branch.filter((entry) => entry.type === "model_change");
	const saved = branch.some((entry) => entry.type === "message") ? changes.at(-1) : changes.at(-2);
	if (saved) {
		if (saved.provider === selected.provider && saved.modelId === selected.id) return;
		return { error: `Datasafe blocked silent model fallback from ${saved.provider}/${saved.modelId} to ${selected.provider}/${selected.id}. Start a new session.`, canSelectModel: false };
	}
	const global = await settings(join(getAgentDir(), "settings.json"));
	const project = ctx.isProjectTrusted() ? await settings(join(ctx.cwd, ".pi", "settings.json")) : {};
	const provider = project.defaultProvider ?? global.defaultProvider;
	const model = project.defaultModel ?? global.defaultModel;
	if (!provider || !model || (provider === selected.provider && model === selected.id)) return;
	const configured = ctx.modelRegistry.find(provider, model);
	if (configured && ctx.modelRegistry.hasConfiguredAuth(configured)) return;
	return { error: `Datasafe blocked silent model fallback from configured default ${provider}/${model} to ${selected.provider}/${selected.id}. Select a model explicitly.`, canSelectModel: true };
}

export function preventModelFallback(pi: ExtensionAPI): void {
	let original: Provider | undefined;
	let canSelectModel = false;
	pi.on("session_start", async (_event, ctx) => {
		if (original) {
			pi.registerProvider(original);
			original = undefined;
		}
		canSelectModel = false;
		let fallback: Fallback | undefined;
		try {
			fallback = await fallbackError(ctx);
		} catch (cause) {
			fallback = { error: `Datasafe could not verify the configured model: ${String(cause)}`, canSelectModel: false };
		}
		if (!fallback || !ctx.model) return;
		const provider = ctx.modelRegistry.getProvider(ctx.model.provider);
		if (!provider) return;
		original = provider;
		canSelectModel = fallback.canSelectModel;
		pi.registerProvider({
			...provider,
			stream: () => { throw new Error(fallback.error); },
			streamSimple: () => { throw new Error(fallback.error); },
		});
	});
	pi.on("model_select", (event) => {
		if (original && canSelectModel && event.source !== "restore") {
			pi.registerProvider(original);
			original = undefined;
			canSelectModel = false;
		}
	});
}
