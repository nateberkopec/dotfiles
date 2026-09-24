import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

/**
 * Compacts every model at 400k tokens, regardless of provider.
 *
 * Pi compacts when context exceeds `contextWindow - reserveTokens`, and that
 * window comes from the selected model. This extension hands Pi a copy of the
 * current model whose window is clamped to the cap, so Pi's own threshold
 * check, mid-run compaction, overflow recovery, and status line all follow.
 * Models whose real window is already at or below the cap are left untouched.
 *
 * `/compact-at <tokens|Nk|Nm|off>` overrides the cap for the current session.
 * The override is stored in the session file, so resuming keeps it. It can
 * raise the cap above 400k but never above the model's real window.
 */
const DEFAULT_CAP_TOKENS = 400_000;
const ENTRY_TYPE = "compact-at";

type Cap = number | null;

export function parseCap(input: string): Cap | undefined {
	const text = input.trim().toLowerCase();
	if (text === "off") return null;
	const match = /^(\d+(?:\.\d+)?)([km])?$/.exec(text);
	if (!match) return undefined;
	const scale = match[2] === "m" ? 1_000_000 : match[2] === "k" ? 1_000 : 1;
	const tokens = Math.round(Number(match[1]) * scale);
	return tokens > 0 ? tokens : undefined;
}

function formatTokens(tokens: number): string {
	return tokens % 1_000 === 0 ? `${tokens / 1_000}k` : String(tokens);
}

function isCap(value: unknown): value is Cap {
	return value === null || (typeof value === "number" && value > 0);
}

function restoreCap(ctx: ExtensionContext): Cap {
	let cap: Cap = DEFAULT_CAP_TOKENS;
	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type !== "custom" || entry.customType !== ENTRY_TYPE) continue;
		const stored = (entry.data as { cap?: unknown } | undefined)?.cap;
		if (isCap(stored)) cap = stored;
	}
	return cap;
}

export default function compactAt(pi: ExtensionAPI) {
	let cap: Cap = DEFAULT_CAP_TOKENS;

	const describe = () =>
		cap === null ? "Compaction cap off: using each model's full context window" : `Compaction cap: ${formatTokens(cap)} tokens`;

	const applyCap = async (ctx: ExtensionContext) => {
		const current = ctx.model;
		if (!current) return;
		const registered = ctx.modelRegistry.find(current.provider, current.id) ?? current;
		const fullWindow = registered.contextWindow;
		if (!(fullWindow > 0)) return;
		const target = cap === null ? fullWindow : Math.min(cap, fullWindow);
		if (current.contextWindow === target) return;
		// Pi recomputes the thinking level on every setModel; keep the session's choice.
		const thinkingLevel = pi.getThinkingLevel();
		if (!(await pi.setModel({ ...registered, contextWindow: target }))) return;
		pi.setThinkingLevel(thinkingLevel);
	};

	pi.on("session_start", async (_event, ctx) => {
		cap = restoreCap(ctx);
		await applyCap(ctx);
	});
	pi.on("model_select", async (_event, ctx) => applyCap(ctx));
	// Provider registration and catalog refreshes replace the session model with
	// the registry copy, which drops the clamp until the next turn.
	pi.on("turn_start", async (_event, ctx) => applyCap(ctx));

	pi.registerCommand("compact-at", {
		description: "Cap this session's context window so compaction triggers earlier (tokens, Nk, Nm, or off)",
		handler: async (args, ctx) => {
			const notify = (message: string, level: "info" | "error") => ctx.hasUI && ctx.ui.notify(message, level);
			if (args.trim()) {
				const parsed = parseCap(args);
				if (parsed === undefined) return notify("Usage: /compact-at <tokens|Nk|Nm|off>", "error");
				cap = parsed;
				pi.appendEntry(ENTRY_TYPE, { cap });
				await applyCap(ctx);
			}
			notify(describe(), "info");
		},
	});
}
