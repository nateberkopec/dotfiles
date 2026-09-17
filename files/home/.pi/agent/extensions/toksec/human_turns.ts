import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { subagentsRunning } from "./subagents.ts";

const CUSTOM_TYPE = "toksec-tbht";
type TurnEntry = { version: 1; startedAt: number; endedAt?: number };

function isTurnEntry(data: unknown): data is TurnEntry {
	if (!data || typeof data !== "object") return false;
	const entry = data as Partial<TurnEntry>;
	return entry.version === 1 && typeof entry.startedAt === "number" && Number.isFinite(entry.startedAt) &&
		(entry.endedAt === undefined || (typeof entry.endedAt === "number" && Number.isFinite(entry.endedAt) && entry.endedAt >= entry.startedAt));
}

/** Mean wall time from human input to a settled parent with no active children. */
export function trackHumanTurns(pi: ExtensionAPI, update: (ctx: ExtensionContext) => void): () => number | undefined {
	let startedAt: number | undefined;
	let totalMs = 0;
	let count = 0;
	let revision = 0;
	const isChild = Number(process.env.PI_SUBAGENT_DEPTH ?? 0) > 0;

	function restore(ctx: ExtensionContext): void {
		revision++;
		startedAt = undefined;
		totalMs = 0;
		count = 0;
		if (isChild) return;
		for (const entry of ctx.sessionManager.getBranch()) {
			if (entry.type !== "custom" || entry.customType !== CUSTOM_TYPE || !isTurnEntry(entry.data)) continue;
			if (entry.data.endedAt === undefined) startedAt = entry.data.startedAt;
			else {
				totalMs += entry.data.endedAt - entry.data.startedAt;
				count++;
				startedAt = undefined;
			}
		}
		update(ctx);
	}

	pi.on("session_start", (_event, ctx) => restore(ctx));
	pi.on("session_tree", (_event, ctx) => restore(ctx));
	pi.on("input", (event) => {
		if (isChild || event.source === "extension") return;
		revision++;
		// Steering and input during background work belong to the existing span.
		if (startedAt !== undefined) return;
		startedAt = Date.now();
		pi.appendEntry(CUSTOM_TYPE, { version: 1, startedAt } satisfies TurnEntry);
	});
	pi.on("agent_start", () => { revision++; });
	const unsubscribe = pi.events.on("subagent:async-started", () => { revision++; });
	pi.on("agent_settled", async (_event, ctx) => {
		if (startedAt === undefined || !ctx.isIdle() || ctx.hasPendingMessages()) return;
		const currentRevision = revision;
		const endedAt = Math.max(startedAt, Date.now());
		if (await subagentsRunning(pi)) return;
		if (currentRevision !== revision || startedAt === undefined || !ctx.isIdle() || ctx.hasPendingMessages()) return;
		pi.appendEntry(CUSTOM_TYPE, { version: 1, startedAt, endedAt } satisfies TurnEntry);
		totalMs += endedAt - startedAt;
		count++;
		startedAt = undefined;
		update(ctx);
	});
	pi.on("session_shutdown", () => { revision++; startedAt = undefined; unsubscribe(); });
	return () => count > 0 ? totalMs / count : undefined;
}
