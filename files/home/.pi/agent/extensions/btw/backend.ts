import type { ExtensionContext, CreateAgentSessionOptions } from "@earendil-works/pi-coding-agent";
import type { AssistantMessage, Message } from "@earendil-works/pi-ai/compat";

export interface ChatSpec {
	id: string;
	title: string;
	model: NonNullable<ExtensionContext["model"]>;
	systemPrompt: string;
	seed: Message[];
	tools: string[];
	strict?: boolean;
	opening?: string;
	thinking?: CreateAgentSessionOptions["thinkingLevel"];
	onUsage?: (message: AssistantMessage) => void;
}
export async function createBackend(ctx: ExtensionContext, spec: ChatSpec, onText: (text: string) => void) {
	const { createAgentSession, createExtensionRuntime, ModelRuntime, SessionManager, SettingsManager } =
		await import("@earendil-works/pi-coding-agent");
	const registry = ctx.modelRegistry, model = spec.model;
	const runtime = await ModelRuntime.create({ modelsPath: null, allowModelNetwork: false, refreshOnCreate: false });
	const native = registry.getRegisteredNativeProvider(model.provider), config = registry.getRegisteredProviderConfig(model.provider);
	if (native) runtime.registerNativeProvider(native);
	if (config) runtime.registerProvider(model.provider, config);
	// Keep the parent's configured authentication, routing and provider policy. No new credentials or fallback.
	runtime.getAuth = (target) => registry.getProviderAuth(typeof target === "string" ? target : target.provider);
	runtime.streamSimple = (requested, context, options) => {
		if (requested.provider !== model.provider || requested.id !== model.id) throw new Error("Side-chat model changed unexpectedly.");
		const stream = registry.streamSimple(requested, context, { ...options, ...(spec.strict ? {
			maxTokens: 1024, reasoning: "low" as const, maxRetries: 0,
			fetch: (input: RequestInfo | URL, init?: RequestInit) => fetch(input, { ...init, redirect: "error" }),
		} : {}) });
		void stream.result().then((message) => spec.onUsage?.(message)).catch(() => {});
		return stream;
	};
	const manager = SessionManager.inMemory(ctx.cwd);
	for (const message of spec.seed) manager.appendMessage(message);
	const { session } = await createAgentSession({
		cwd: ctx.cwd, modelRuntime: runtime, model, tools: spec.tools, sessionManager: manager,
		thinkingLevel: spec.strict ? "low" : spec.thinking ?? "off",
		settingsManager: SettingsManager.inMemory({ compaction: { enabled: false }, retry: { enabled: false }, cacheWarming: "off" }),
		resourceLoader: {
			getExtensions: () => ({ extensions: [], errors: [], runtime: createExtensionRuntime() }),
			getSkills: () => ({ skills: [], diagnostics: [] }), getPrompts: () => ({ prompts: [], diagnostics: [] }),
			getThemes: () => ({ themes: [], diagnostics: [] }), getAgentsFiles: () => ({ agentsFiles: [] }),
			getSystemPrompt: () => spec.systemPrompt, getSystemPromptSource: () => undefined,
			getAppendSystemPrompt: () => [], getAppendSystemPromptSources: () => [],
			extendResources() {}, reload: async () => {},
		},
	});
	const unsubscribe = session.subscribe((event) => {
		if (event.type === "message_update" && event.message.role === "assistant") onText(textOf(event.message));
	});
	return {
		async run(question: string) {
			const start = session.messages.length;
			await session.prompt(question, { source: "extension", expandPromptTemplates: false });
			const messages = session.messages.slice(start);
			const message = [...messages].reverse().find((m) => m.role === "assistant") as AssistantMessage | undefined;
			if (!message || message.stopReason === "error" || message.stopReason === "aborted") throw new Error("Side-chat response failed.");
			return { message, messages: messages as Message[] };
		},
		close() { unsubscribe(); session.dispose(); },
	};
}
export function textOf(message: { content: unknown }) {
	const text = typeof message.content === "string" ? message.content : Array.isArray(message.content)
		? message.content.filter((b) => b.type === "text").map((b) => b.text).join("\n") : "";
	return text.replace(/[\u0000-\u0008\u000b-\u001f\u007f-\u009f]/g, "").trim();
}
