import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { formatStatus } from "./format.ts";
import { addSample, currentModel, rebuildStats, sameModel, zeroStats } from "./samples.ts";
import {
	charsFromMessage,
	deltaCharsFromEvent,
	isFinalAssistantMessage,
	isOutputEvent,
	outputTokensFromMessage,
} from "./stream_events.ts";
import { CUSTOM_TYPE, STATUS_KEY, type ActiveMeasurement, type AggregateStats, type ModelRef, type ToksecEntry } from "./types.ts";

function updateStatus(ctx: ExtensionContext, stats: AggregateStats): void {
	if (!ctx.hasUI) return;
	ctx.ui.setStatus(STATUS_KEY, ctx.ui.theme.fg("dim", formatStatus(stats)));
}

function createSample(message: unknown, measurement: ActiveMeasurement): ToksecEntry | undefined {
	const firstOutputAt = measurement.firstOutputAt;
	if (!firstOutputAt) return undefined;

	const observedChars = Math.max(measurement.observedChars, charsFromMessage(message));

	return {
		version: 1,
		kind: "sample",
		provider: measurement.model.provider,
		modelId: measurement.model.id,
		outputTokens: outputTokensFromMessage(message, observedChars),
		generationMs: Date.now() - firstOutputAt,
		ttftMs: firstOutputAt - measurement.requestStartedAt,
		timestamp: new Date().toISOString(),
	};
}

export default function toksecExtension(pi: ExtensionAPI) {
	let stats = zeroStats();
	let active: ActiveMeasurement | undefined;
	let pendingRequestStartedAt: number | undefined;
	let selectedModel: ModelRef | undefined;

	pi.on("session_start", async (_event, ctx) => {
		selectedModel = currentModel(ctx);
		stats = rebuildStats(ctx, selectedModel);
		updateStatus(ctx, stats);
	});

	pi.on("before_provider_request", async (_event, ctx) => {
		pendingRequestStartedAt = Date.now();
		selectedModel = currentModel(ctx) ?? selectedModel;
	});

	pi.on("message_start", async (event, ctx) => {
		const message = event.message as { role?: unknown };
		if (message.role !== "assistant") return;

		const model = currentModel(ctx) ?? selectedModel;
		if (!model) return;

		active = {
			model,
			requestStartedAt: pendingRequestStartedAt ?? Date.now(),
			observedChars: 0,
		};
		pendingRequestStartedAt = undefined;
	});

	pi.on("message_update", async (event) => {
		if (!active) return;

		const assistantEvent = event.assistantMessageEvent;
		if (!isOutputEvent(assistantEvent)) return;

		active.firstOutputAt ??= Date.now();

		// Count the whole assistant payload (text + thinking + tool calls), not just
		// text deltas. Prefer the running partial message; also accumulate raw deltas
		// for providers that omit partial content on some events.
		active.observedChars = Math.max(
			active.observedChars + deltaCharsFromEvent(assistantEvent),
			charsFromMessage(event.message),
		);
	});

	pi.on("message_end", async (event, ctx) => {
		if (!active) return;
		const measurement = active;
		active = undefined;

		if (!isFinalAssistantMessage(event.message)) return updateStatus(ctx, stats);
		if (!sameModel(measurement.model, selectedModel ?? currentModel(ctx))) return updateStatus(ctx, stats);

		// Non-streaming completions skip message_update; still count the final payload.
		const finalChars = charsFromMessage(event.message);
		if (!measurement.firstOutputAt && finalChars > 0) {
			measurement.firstOutputAt = Date.now();
			measurement.observedChars = Math.max(measurement.observedChars, finalChars);
		}

		const sample = createSample(event.message, measurement);
		if (!sample) return updateStatus(ctx, stats);

		const previousCount = stats.count;
		addSample(stats, sample);
		if (stats.count > previousCount) pi.appendEntry(CUSTOM_TYPE, sample);
		updateStatus(ctx, stats);
	});

	pi.on("model_select", async (event, ctx) => {
		selectedModel = { provider: event.model.provider, id: event.model.id };
		active = undefined;
		pendingRequestStartedAt = undefined;
		stats = event.source === "restore" ? rebuildStats(ctx, selectedModel) : zeroStats();
		updateStatus(ctx, stats);
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		if (ctx.hasUI) ctx.ui.setStatus(STATUS_KEY, undefined);
	});
}
