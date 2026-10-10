import { createAssistantMessageEventStream, getCurrentSystemPrompt, getCurrentTools } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function fixture(pi: ExtensionAPI) {
	pi.registerProvider("btw-test", {
		api: "btw-test-api",
		apiKey: "fixture-not-a-secret",
		baseUrl: "https://invalid.example",
		models: [
			{
				id: "assistant",
				name: "BTW fixture",
				reasoning: false,
				input: ["text"],
				cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
				contextWindow: 64000,
				maxTokens: 1024,
			},
		],
		streamSimple(model, context) {
			const stream = createAssistantMessageEventStream();
			pi.appendEntry("side-chat-fixture-request", {
				provider: model.provider,
				model: model.id,
				system: getCurrentSystemPrompt(context.messages),
				tools: getCurrentTools(context.messages).map((tool) => tool.name),
				source: JSON.stringify(context.messages),
			});

			const message = {
				role: "assistant" as const,
				api: model.api,
				provider: model.provider,
				model: model.id,
				content: [{ type: "text" as const, text: "Check that the backup can be restored." }],
				stopReason: "stop" as const,
				timestamp: Date.now(),
				usage: {
					input: 10,
					output: 10,
					cacheRead: 0,
					cacheWrite: 0,
					totalTokens: 20,
					cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
				},
			};

			queueMicrotask(() => {
				stream.push({ type: "done", reason: "stop", message });
				stream.end();
			});

			return stream;
		},
	});
}
