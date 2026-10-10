import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STATUS_KEY = "cache-hit-warning";

function updateStatus(ctx: ExtensionContext, usage?: AssistantMessage["usage"]): void {
	if (!ctx.hasUI) return;
	const promptTokens = usage ? usage.input + usage.cacheRead + usage.cacheWrite : 0;
	const warn = usage && promptTokens > 0 && usage.cacheRead / promptTokens < 0.95;
	ctx.ui.setStatus(STATUS_KEY, warn ? ctx.ui.theme.bold(ctx.ui.theme.fg("error", "[ CH WARNING ]")) : undefined);
}

export default function cacheHitWarning(pi: ExtensionAPI) {
	function restoreStatus(ctx: ExtensionContext): void {
		const entries = ctx.sessionManager.getEntries();

		for (let i = entries.length - 1; i >= 0; i--) {
			const entry = entries[i];

			if (entry.type === "message" && entry.message.role === "assistant") {
				updateStatus(ctx, entry.message.usage);

				return;
			}
		}

		updateStatus(ctx);
	}

	pi.on("session_start", (_event, ctx) => restoreStatus(ctx));
	pi.on("session_tree", (_event, ctx) => restoreStatus(ctx));
	pi.on("message_end", (event, ctx) => {
		if (event.message.role === "assistant") updateStatus(ctx, event.message.usage);
	});
	pi.on("session_shutdown", (_event, ctx) => updateStatus(ctx));
}
