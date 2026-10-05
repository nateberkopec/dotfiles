import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import { decide } from "./jev.ts";
import { usageRecord, type UsageRecord } from "./usage.ts";

import { NOTE_INSTRUCTIONS } from "./prompt.ts";
import type { TopicHistory } from "./history.ts";

export async function reviewTranscript(ctx: ExtensionContext, source: string, history: TopicHistory, threshold: number,
	signal: AbortSignal, onUsage: (record: UsageRecord) => void, onWaiting: (active: boolean) => void,
	onExplaining: () => Promise<void> = async () => {}) {
	const model = ctx.modelRegistry.find("openai", "gpt-6-luna");
	if (!model) throw new Error("openai/gpt-6-luna is unavailable in this Datasafe profile.");
	const waitFor = async <T>(call: () => Promise<T>): Promise<T> => {
		signal.throwIfAborted(); onWaiting(true);
		try { return await call(); } finally { onWaiting(false); }
	};
	const state = history.state(source);
	const decision = await waitFor(() => decide(state, signal));
	onUsage(usageRecord("jev", decision.usage)); signal.throwIfAborted();
	if (decision.choice !== "warn" || decision.category === "none" || decision.confidence < threshold) return { decision, note: "" };
	await onExplaining(); signal.throwIfAborted();
	const response = await waitFor(() => ctx.modelRegistry.streamSimple(model, {
		systemPrompt: NOTE_INSTRUCTIONS,
		messages: [{ role: "user", content: state, timestamp: Date.now() }],
	}, { signal, maxTokens: 512, reasoning: "low", maxRetries: 0,
		fetch: (input, init) => fetch(input, { ...init, redirect: "error" }),
	}).result());
	const interrupted = response.stopReason === "error" || response.stopReason === "aborted";
	onUsage(usageRecord("luna", response.usage, interrupted)); signal.throwIfAborted();
	if (interrupted) throw new Error("Luna failed; no note was fabricated.");
	const text = response.content.filter((block) => block.type === "text").map((block) => block.text).join(" ")
		.replace(/[\u0000-\u001f\u007f-\u009f]/g, " ").trim().slice(0, 600);
	return { decision, note: !text || /^NONE[.!]?$/i.test(text) ? "" : text };
}
