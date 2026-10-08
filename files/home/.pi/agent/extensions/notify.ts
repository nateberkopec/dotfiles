/**
 * Adapted from mitsuhiko/agent-stuff extensions/notify.ts at 0865c849befd2021490679f96a8dee58c84ac857.
 * Licensed under Apache-2.0; see NOTIFY-LICENSE.txt.
 *
 * Desktop Notification Extension
 *
 * Sends a native desktop notification when the agent finishes and is waiting for input.
 * Uses OSC 777 escape sequence - no external dependencies.
 *
 * Supported terminals: Ghostty, iTerm2, WezTerm, rxvt-unicode
 * Not supported: Kitty (uses OSC 99), Terminal.app, Windows Terminal, Alacritty
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { Message } from "@earendil-works/pi-ai/compat";
import { messageText } from "./shared/message_text.ts";
import { subagentsRunning } from "./notify/readiness.ts";
import { Markdown, type MarkdownTheme, stripTerminalSequences } from "@earendil-works/pi-tui";

/**
 * Send a desktop notification via OSC 777 escape sequence.
 */
const notify = (title: string, body: string): void => {
	// OSC 777 format: ESC ] 777 ; notify ; title ; body BEL
	process.stdout.write(`\x1b]777;notify;${title};${body}\x07`);
};

type NotificationMessage = { role?: string; content?: Message["content"] };

const extractLastAssistantText = (messages: readonly NotificationMessage[]): string | null => {
	for (let i = messages.length - 1; i >= 0; i--) {
		const message = messages[i];

		if (message?.role !== "assistant") {
			continue;
		}

		return messageText(message.content).trim() || null;
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

const formatNotification = (text: string | null) => {
	const simplified = text ? simpleMarkdown(text) : "";

	// Markdown emits OSC 8 hyperlinks. Embedding one OSC sequence inside the OSC
	// 777 notification terminates the notification early and prints its visible
	// text at the terminal cursor. Remove terminal sequences and remaining control
	// characters before constructing the outer OSC sequence.
	const normalized = stripTerminalSequences(simplified)
		.replace(/\p{Cc}/gu, " ")
		.replace(/\s+/g, " ")
		.trim();

	if (!normalized) {
		return { title: "Ready for input", body: "" };
	}

	const maxBody = 200;
	const body = normalized.length > maxBody ? `${normalized.slice(0, maxBody - 1)}…` : normalized;

	return { title: "π", body };
};

export default function (pi: ExtensionAPI) {
	let lastText: string | null = null;
	let armed = false;
	let revision = 0;

	const reset = () => {
		revision++;
		armed = false;
		lastText = null;
	};

	const busy = () => {
		revision++;
		armed = true;
	};

	pi.on("session_start", reset);
	pi.on("session_tree", reset);
	pi.on("agent_start", busy);
	const unsubscribe = pi.events.on("subagent:async-started", busy);
	pi.on("agent_end", (event) => {
		lastText = extractLastAssistantText(event.messages ?? []);
	});
	// agent_end may be followed by retries, queued messages, or a background child.
	// Only the parent's settled follow-up can establish that a human is needed.
	pi.on("agent_settled", async (_event, ctx) => {
		if (ctx.mode !== "tui" || !armed || !ctx.isIdle() || ctx.hasPendingMessages()) return;
		const currentRevision = revision;

		if (await subagentsRunning(pi)) return;

		if (currentRevision !== revision || !armed || !ctx.isIdle() || ctx.hasPendingMessages()) return;
		armed = false;
		const { title, body } = formatNotification(lastText);
		notify(title, body);
	});
	pi.on("session_shutdown", () => {
		reset();
		unsubscribe();
	});
}
