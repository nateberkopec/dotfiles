/**
 * Desktop Notification Extension
 *
 * Sends a native desktop notification when the agent finishes and is waiting for input.
 * Uses OSC 777 escape sequence - no external dependencies.
 *
 * Supported terminals: Ghostty, iTerm2, WezTerm, rxvt-unicode
 * Not supported: Kitty (uses OSC 99), Terminal.app, Windows Terminal, Alacritty
 */

// Adapted from https://github.com/mitsuhiko/agent-stuff/blob/0865c849befd2021490679f96a8dee58c84ac857/extensions/notify.ts (Apache-2.0).
// Readiness follows pi-ding's session/subagent gate (MIT).
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { randomUUID } from "node:crypto";
import { ReadyNotificationGate } from "./notify_readiness.ts";
import { Markdown, type MarkdownTheme, stripTerminalSequences } from "@earendil-works/pi-tui";

/**
 * Send a desktop notification via OSC 777 escape sequence.
 */
const notify = (title: string, body: string): void => {
	// OSC 777 format: ESC ] 777 ; notify ; title ; body BEL
	process.stdout.write(`\x1b]777;notify;${title};${body}\x07`);
};

const isTextPart = (part: unknown): part is { type: "text"; text: string } =>
	Boolean(part && typeof part === "object" && "type" in part && part.type === "text" && "text" in part);

const extractLastAssistantText = (messages: Array<{ role?: string; content?: unknown }>): string | null => {
	for (let i = messages.length - 1; i >= 0; i--) {
		const message = messages[i];
		if (message?.role !== "assistant") {
			continue;
		}

		const content = message.content;
		if (typeof content === "string") {
			return content.trim() || null;
		}

		if (Array.isArray(content)) {
			const text = content.filter(isTextPart).map((part) => part.text).join("\n").trim();
			return text || null;
		}

		return null;
	}

	return null;
};

const plainMarkdownTheme: MarkdownTheme = {
	heading: (text) => text,
	link: (text) => text,
	linkUrl: () => "",
	code: (text) => text,
	codeBlock: (text) => text,
	codeBlockBorder: () => "",
	quote: (text) => text,
	quoteBorder: () => "",
	hr: () => "",
	listBullet: () => "",
	bold: (text) => text,
	italic: (text) => text,
	strikethrough: (text) => text,
	underline: (text) => text,
};

const simpleMarkdown = (text: string, width = 80): string => {
	const markdown = new Markdown(text, 0, 0, plainMarkdownTheme);
	return markdown.render(width).join("\n");
};

const formatNotification = (text: string | null): { title: string; body: string } => {
	const simplified = text ? simpleMarkdown(text) : "";
	// Markdown emits OSC 8 hyperlinks. Embedding one OSC sequence inside the OSC
	// 777 notification terminates the notification early and prints its visible
	// text at the terminal cursor. Remove terminal sequences and remaining control
	// characters before constructing the outer OSC sequence.
	const normalized = stripTerminalSequences(simplified)
		.replace(/[\x00-\x1f\x7f-\x9f]/g, " ")
		.replace(/\s+/g, " ")
		.trim();
	if (!normalized) {
		return { title: "Ready for input", body: "" };
	}

	const maxBody = 200;
	const body = normalized.length > maxBody ? `${normalized.slice(0, maxBody - 1)}…` : normalized;
	return { title: "π", body };
};

const SCHEDULE_ENTRY = "pi-notify-schedule";
type ScheduleOperation = { action: "schedule.create" | "schedule.pause" | "schedule.delete"; id?: string };

function record(value: unknown): Record<string, unknown> {
	return value !== null && typeof value === "object" ? value as Record<string, unknown> : {};
}

function restoredScheduleIds(ctx: ExtensionContext): Set<string> {
	const ids = new Set<string>();
	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type !== "custom" || entry.customType !== SCHEDULE_ENTRY) continue;
		const data = record(entry.data);
		if (data.version !== 1 || typeof data.id !== "string") continue;
		if (data.action === "track") ids.add(data.id);
		if (data.action === "untrack") ids.delete(data.id);
	}
	return ids;
}

function requestSubagent(pi: ExtensionAPI, method: "status" | "manage", params?: Record<string, unknown>): Promise<unknown> {
	if (!pi.getAllTools().some((tool) => tool.name === "subagent")) {
		return Promise.resolve({ success: true, data: { fleet: { version: 1, totalActive: 0 }, details: { schedules: { records: [] } } } });
	}
	const requestId = randomUUID();
	return new Promise((resolve, reject) => {
		const timeout = setTimeout(() => {
			unsubscribe();
			reject(new Error(`pi-notify: pi-subagents ${method} request timed out`));
		}, 2000);
		const unsubscribe = pi.events.on(`subagents:rpc:v1:reply:${requestId}`, (reply) => {
			clearTimeout(timeout);
			unsubscribe();
			resolve(reply);
		});
		pi.events.emit("subagents:rpc:v1:request", { version: 1, requestId, method, ...(params ? { params } : {}) });
	});
}

export default function (pi: ExtensionAPI) {
	let lastContext: ExtensionContext | undefined;
	let lastText: string | null = null;
	let wakeTimer: ReturnType<typeof setTimeout> | undefined;
	const scheduleOperations = new Map<string, ScheduleOperation>();
	const gate = new ReadyNotificationGate((method, params) => requestSubagent(pi, method, params), () => {
		if (lastContext?.hasUI && lastContext.mode === "tui") {
			const { title, body } = formatNotification(lastText);
			notify(title, body);
		}
	});

	function wake(ctx: ExtensionContext): void {
		lastContext = ctx;
		if (wakeTimer !== undefined) clearTimeout(wakeTimer);
		wakeTimer = setTimeout(() => {
			wakeTimer = undefined;
			void gate.settle(ctx).catch((error) => ctx.ui.notify(error instanceof Error ? error.message : String(error), "warning"));
		}, 0);
	}

	function startSession(ctx: ExtensionContext): void {
		lastContext = ctx;
		lastText = null;
		gate.reset(restoredScheduleIds(ctx));
	}

	pi.on("session_start", (_event, ctx) => startSession(ctx));
	pi.on("session_tree", (_event, ctx) => startSession(ctx));
	pi.on("input", () => gate.markBusy());
	pi.on("agent_start", () => gate.markBusy());
	pi.on("agent_end", (event) => { lastText = extractLastAssistantText(event.messages ?? []); });
	pi.on("agent_settled", async (_event, ctx) => {
		lastContext = ctx;
		if (ctx.mode === "tui") await gate.settle(ctx);
	});
	const startedUnsubscribe = pi.events.on("subagent:async-started", () => gate.markBusy());
	const completeUnsubscribe = pi.events.on("subagent:async-complete", () => {
		if (lastContext?.mode === "tui") wake(lastContext);
	});
	const terminalUnsubscribe = pi.events.on("subagent:process-terminal", () => {
		if (lastContext?.mode === "tui") wake(lastContext);
	});

	pi.on("tool_call", (event) => {
		if (event.toolName !== "subagent") return;
		const input = record(event.input);
		const action = input.action;
		if (action !== "schedule.create" && action !== "schedule.pause" && action !== "schedule.delete") return;
		scheduleOperations.set(event.toolCallId, { action, ...(typeof input.id === "string" ? { id: input.id } : {}) });
	});
	pi.on("tool_result", (event) => {
		const operation = scheduleOperations.get(event.toolCallId);
		scheduleOperations.delete(event.toolCallId);
		if (!operation || event.isError) return;
		if (operation.action === "schedule.create") {
			const records = record(record(event.details).schedules).records;
			if (!Array.isArray(records)) return;
			for (const item of records) {
				const id = record(item).id;
				if (typeof id !== "string") continue;
				gate.trackSchedule(id);
				pi.appendEntry(SCHEDULE_ENTRY, { version: 1, action: "track", id });
			}
		} else if (operation.action === "schedule.delete" && operation.id) {
			gate.untrackSchedule(operation.id);
			pi.appendEntry(SCHEDULE_ENTRY, { version: 1, action: "untrack", id: operation.id });
		}
	});
	pi.on("session_shutdown", () => {
		if (wakeTimer !== undefined) clearTimeout(wakeTimer);
		startedUnsubscribe();
		completeUnsubscribe();
		terminalUnsubscribe();
	});
}
