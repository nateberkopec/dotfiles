import { createAssistantMessageEventStream, getCurrentSystemPrompt, getCurrentTools } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { JEV_MODEL, JEV_URL } from "../../files/home/.pi/agent/extensions/you-should-know/jev.ts";

// Deterministic, network-free provider for testing the real Pi session lifecycle.
export default function fixture(pi: ExtensionAPI) {
	if (!process.env.YSK_FIXTURE_REAL_JEV) {
		process.env.TYPESAFE_API_KEY = "fixture-not-a-secret";
		globalThis.fetch = async (url, options) => {
			if (url !== JEV_URL) throw new Error("Unexpected network request in fixture");
			const body = JSON.parse(String(options?.body));

			if (body.model !== JEV_MODEL || Object.keys(body.questions).length !== 2)
				throw new Error("Expected one pinned batched decision");
			const p = body.state.includes("backup") ? 1 : 0;

			return new Response(
				JSON.stringify({
					model: JEV_MODEL,
					usage: { input_tokens: 100 },
					answers: {
						interrupt: {
							type: "choice",
							choice: p ? "warn" : "quiet",
							confidence: 1,
							probabilities: { warn: p, quiet: 1 - p },
						},
						category: {
							type: "choice",
							choice: "wrong_result",
							confidence: 1,
							probabilities: { wrong_result: 1, cost: 0, wasted_work: 0, data_loss: 0, security: 0, none: 0 },
						},
					},
				}),
			);
		};
	}

	for (const [provider, id] of [
		["ysk-test", "observer"],
		["openai", "gpt-6-luna"],
	] as const) {
		if (provider === "openai" && process.env.YSK_FIXTURE_REAL_LUNA) continue;
		pi.registerProvider(provider, {
			api: "ysk-test-api",
			apiKey: "fixture-not-a-secret",
			baseUrl: "https://invalid.example",
			models: [
				{
					id,
					name: "Observer fixture",
					reasoning: false,
					input: ["text"],
					cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
					contextWindow: 64000,
					maxTokens: 1024,
				},
			],
			streamSimple(model, context) {
				const stream = createAssistantMessageEventStream();
				const system = getCurrentSystemPrompt(context.messages);
				const observer = system.includes("quiet, independent");
				pi.appendEntry("side-chat-fixture-request", {
					provider: model.provider,
					model: model.id,
					system,
					tools: getCurrentTools(context.messages).map((tool) => tool.name),
					source: JSON.stringify(context.messages),
				});

				if (observer && getCurrentTools(context.messages).length) throw new Error("Observer must have no tools");

				if (observer && (model.provider !== "openai" || model.id !== "gpt-6-luna"))
					throw new Error("Observer must use the pinned Luna model");
				const source = JSON.stringify(context.messages);

				const text = observer
					? source.includes("backup")
						? "Verify the backup can be restored before deleting the database."
						: "NONE"
					: source.includes("backup")
						? "I will delete the database now and check the backup afterward."
						: "2 + 2 = 4.";

				const message = {
					role: "assistant" as const,
					api: model.api,
					provider: model.provider,
					model: model.id,
					content: [{ type: "text" as const, text }],
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
}
