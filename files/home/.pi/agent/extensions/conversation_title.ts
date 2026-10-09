import { writeFileSync } from "node:fs";
import path from "node:path";
import { uuidv7 } from "@earendil-works/pi-ai";
import { complete } from "@earendil-works/pi-ai/compat";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { auxiliaryHeaders } from "./meridian/requests.ts";
import { messageText as extractText } from "./shared/message_text.ts";
import { Type } from "typebox";
import { Value } from "typebox/value";

const STATE_KEY = "conversation-title";

const TITLE_INTERVAL_MS = 10 * 60 * 1000;

const MAX_CONVERSATION_CHARS = 12_000;

const SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

type StoredState = { title?: string; updatedAt?: number };

const StoredState = Type.Object({ title: Type.Optional(Type.String()), updatedAt: Type.Optional(Type.Number()) });

function conversationText(ctx: ExtensionContext): string {
	const messages = ctx.sessionManager
		.getBranch()
		.flatMap((entry) => {
			if (entry.type !== "message") return [];
			const message = entry.message;

			if (message.role !== "user" && message.role !== "assistant") return [];
			const text = `${message.role}: ${extractText(message.content)}`;

			return text.endsWith(": ") ? [] : [text];
		})
		.join("\n\n");

	return messages.slice(-MAX_CONVERSATION_CHARS);
}

function cleanTitle(text: string): string | undefined {
	return (
		text
			.split("\n")
			.find((line) => line.trim())
			?.replace(/^title\s*:\s*/i, "")
			.replace(/\p{Cc}/gu, "")
			.replace(/^['"`]+|['"`]+$/g, "")
			.replace(/[.?!]+$/, "")
			.trim()
			.slice(0, 27)
			.trim() || undefined
	);
}

function writeGhostty(sequence: string): void {
	if (process.env.TERM_PROGRAM !== "ghostty") return;

	try {
		writeFileSync("/dev/tty", sequence);
	} catch {
		// A controlling TTY is unavailable in print and subagent modes.
	}
}

function setProgress(state: number, value?: number): void {
	const progress = value === undefined ? `${state}` : `${state};${value}`;
	writeGhostty(`\x1b]9;4;${progress}\x07`);
}

export default function conversationTitle(pi: ExtensionAPI) {
	let title = "Pi";
	let lastSource = "";
	let lastUpdatedAt = 0;
	let working = false;
	let frame = 0;
	const activeTools = new Map<string, string>();
	let spinnerTimer: ReturnType<typeof setInterval> | undefined;
	let completionTimer: ReturnType<typeof setTimeout> | undefined;
	let restoreTimer: ReturnType<typeof setTimeout> | undefined;
	let titleRequest: AbortController | undefined;

	const displayTitle = (ctx: ExtensionContext, spinner?: string) => {
		const segments = [`π · ${title}`];
		const currentTool = Array.from(activeTools.values()).at(-1);

		if (currentTool) segments.push(currentTool);
		ctx.ui.setTitle(spinner ? `${spinner} ${segments.join(" · ")}` : segments.join(" · "));
	};

	const stopTimers = () => {
		if (spinnerTimer) clearInterval(spinnerTimer);

		if (completionTimer) clearTimeout(completionTimer);

		if (restoreTimer) clearTimeout(restoreTimer);
		spinnerTimer = undefined;
		completionTimer = undefined;
		restoreTimer = undefined;
	};

	const restoreTitleAfterPi = (ctx: ExtensionContext) => {
		if (restoreTimer) clearTimeout(restoreTimer);
		restoreTimer = setTimeout(() => {
			displayTitle(ctx);
			restoreTimer = undefined;
		}, 0);
	};

	const cancelTitleRequest = () => {
		titleRequest?.abort();
		titleRequest = undefined;
	};

	const updateTitle = async (ctx: ExtensionContext) => {
		const source = conversationText(ctx);
		const model = ctx.model;

		if (working || titleRequest || !source || source === lastSource || !model) return;

		if (lastUpdatedAt && Date.now() - lastUpdatedAt < TITLE_INTERVAL_MS) return;

		const controller = new AbortController();
		titleRequest = controller;

		try {
			const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);

			if (!auth.ok || !auth.apiKey || controller.signal.aborted) return;

			const sessionId = uuidv7();

			const response = await complete(
				model,
				{
					messages: [
						{
							role: "user",
							content: [
								{
									type: "text",
									text:
										"Write a specific 2-6 word terminal tab title of at most 27 characters including spaces describing the outcome this conversation is trying to accomplish. Phrase as GTD-style action beginning with a verb. Output only the title.\n\n" +
										source,
								},
							],
							timestamp: Date.now(),
						},
					],
				},
				{
					apiKey: auth.apiKey,
					headers: auxiliaryHeaders(auth.headers, "title", sessionId),
					env: auth.env,
					maxTokens: 64,
					reasoningEffort: "low",
					cacheRetention: "none",
					sessionId,
					signal: controller.signal,
					timeoutMs: 15_000,
					maxRetries: 0,
				},
			);

			if (response.stopReason === "error") {
				throw new Error(response.errorMessage || "Title generation failed");
			}

			const generatedTitle = cleanTitle(extractText(response.content));

			if (!generatedTitle) return;

			title = generatedTitle;
			lastSource = source;
			lastUpdatedAt = Date.now();
			pi.appendEntry(STATE_KEY, { title, updatedAt: lastUpdatedAt });
			displayTitle(ctx);
		} catch (error) {
			if (!controller.signal.aborted) {
				console.warn(`[conversation-title] ${error instanceof Error ? error.message : error}`);
			}
		} finally {
			if (titleRequest === controller) titleRequest = undefined;
		}
	};

	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		let stored: StoredState | undefined;

		for (const entry of ctx.sessionManager.getBranch().toReversed()) {
			if (entry.type === "custom" && entry.customType === STATE_KEY) {
				stored = Value.Check(StoredState, entry.data) ? entry.data : undefined;
				break;
			}
		}

		title = stored?.title || pi.getSessionName() || path.basename(ctx.cwd);
		lastUpdatedAt = stored?.updatedAt || 0;
		restoreTitleAfterPi(ctx);
	});

	pi.on("session_info_changed", (_event, ctx) => {
		if (ctx.mode === "tui") restoreTitleAfterPi(ctx);
	});

	pi.on("agent_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		working = true;
		cancelTitleRequest();

		if (spinnerTimer) clearInterval(spinnerTimer);

		if (completionTimer) clearTimeout(completionTimer);
		completionTimer = undefined;
		setProgress(3);
		frame = 0;
		spinnerTimer = setInterval(() => displayTitle(ctx, SPINNER_FRAMES[frame++ % SPINNER_FRAMES.length]), 80);
	});

	pi.on("tool_execution_start", (event, ctx) => {
		if (ctx.mode === "tui") activeTools.set(event.toolCallId, event.toolName);
	});

	pi.on("tool_execution_end", (event, ctx) => {
		if (ctx.mode === "tui") activeTools.delete(event.toolCallId);
	});

	pi.on("agent_settled", async (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		working = false;

		if (spinnerTimer) clearInterval(spinnerTimer);
		spinnerTimer = undefined;
		activeTools.clear();
		displayTitle(ctx);
		setProgress(1, 100);
		completionTimer = setTimeout(() => {
			setProgress(0);
			completionTimer = undefined;
		}, 800);
		await updateTitle(ctx);
	});

	pi.on("session_shutdown", (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		working = false;
		cancelTitleRequest();
		activeTools.clear();
		stopTimers();
		setProgress(0);
	});
}
