import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { JEV_MODEL, JEV_URL } from "../../files/home/.pi/agent/extensions/you-should-know/jev.ts";

// Uses the real SDK OpenAI adapter with a mocked HTTP/SSE transport. Never accesses the network.
export default function transport(pi: ExtensionAPI) {
	process.env.TYPESAFE_API_KEY = "fixture-not-a-secret";
	pi.registerProvider("openai", {
		api: "openai-responses",
		apiKey: "fixture-not-a-secret",
		baseUrl: "https://openai.invalid/v1",
		models: [
			{
				id: "gpt-6-luna",
				name: "Luna transport fixture",
				reasoning: false,
				input: ["text"],
				cost: { input: 1, output: 1, cacheRead: 1, cacheWrite: 1 },
				contextWindow: 64000,
				maxTokens: 1024,
			},
		],
	});
	globalThis.fetch = async (input, init) => {
		const url = new Request(input, init).url;

		if (url !== JEV_URL && url !== "https://openai.invalid/v1/responses")
			throw new Error("Unexpected fixture network request");
		pi.appendEntry("ysk-transport-check", { url, redirect: init?.redirect });

		if (init?.redirect !== "error") throw new Error("Transcript transport must reject redirects");

		if (url === JEV_URL)
			return new Response(
				JSON.stringify({
					model: JEV_MODEL,
					usage: { input_tokens: 100 },
					answers: {
						interrupt: { type: "choice", choice: "warn", confidence: 1, probabilities: { warn: 1, quiet: 0 } },
						category: {
							type: "choice",
							choice: "data_loss",
							confidence: 1,
							probabilities: { wrong_result: 0, cost: 0, wasted_work: 0, data_loss: 1, security: 0, none: 0 },
						},
					},
				}),
			);
		const item = { type: "message", id: "msg_fixture", role: "assistant", status: "in_progress", content: [] };

		const events: unknown[] = [
			{ type: "response.output_item.added", output_index: 0, item },
			{
				type: "response.output_text.delta",
				output_index: 0,
				content_index: 0,
				item_id: item.id,
				delta: "Verify the backup before deleting the database.",
			},
		];

		if (process.env.YSK_TRANSPORT_FIXTURE !== "interrupted")
			events.push({
				type: "response.completed",
				response: {
					id: "resp_fixture",
					status: "completed",
					output: [],
					usage: { input_tokens: 100, output_tokens: 10, total_tokens: 110 },
				},
			});

		return new Response(events.map((event) => `data: ${JSON.stringify(event)}\n\n`).join(""), {
			headers: { "Content-Type": "text/event-stream" },
		});
	};
}
