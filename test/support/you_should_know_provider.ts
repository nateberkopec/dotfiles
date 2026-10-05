import { AssistantMessageEventStream, getCurrentSystemPrompt, getCurrentTools } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Deterministic, network-free provider for testing the real Pi session lifecycle.
export default function fixture(pi: ExtensionAPI) {
	for (const [provider, id] of [["ysk-test", "observer"], ["openai", "gpt-6-luna"]] as const) {
	pi.registerProvider(provider, {
		api: "ysk-test-api", apiKey: "fixture-not-a-secret", baseUrl: "https://invalid.example",
		models: [{ id, name: "Observer fixture", reasoning: false, input: ["text"],
			cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 64000, maxTokens: 1024 }],
		streamSimple(model, context) {
			const stream = new AssistantMessageEventStream();
			const observer = getCurrentSystemPrompt(context.messages).includes("quiet, independent observer");
			if (observer && getCurrentTools(context.messages).length) throw new Error("Observer must have no tools");
			if (observer && (model.provider !== "openai" || model.id !== "gpt-6-luna")) throw new Error("Observer must use the pinned Luna model");
			const source = JSON.stringify(context.messages);
			const text = observer ? source.includes("backup") ? "Verify the backup can be restored before deleting the database." : "NONE"
				: source.includes("backup") ? "I will delete the database now and check the backup afterward." : "2 + 2 = 4.";
			const message = { role: "assistant" as const, api: model.api, provider: model.provider, model: model.id,
				content: [{ type: "text" as const, text }], stopReason: "stop" as const, timestamp: Date.now(),
				usage: { input: 10, output: 10, cacheRead: 0, cacheWrite: 0, totalTokens: 20,
					cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } } };
			queueMicrotask(() => { stream.push({ type: "done", reason: "stop", message }); stream.end(); });
			return stream;
		},
	});
	}
}
