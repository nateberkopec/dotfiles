const OUTPUT_EVENT_TYPES = new Set([
	"text_start",
	"text_delta",
	"text_end",
	"thinking_start",
	"thinking_delta",
	"thinking_end",
	"toolcall_start",
	"toolcall_delta",
	"toolcall_end",
]);

function isRecord(value: unknown): value is Record<string, unknown> {
	return Boolean(value) && typeof value === "object";
}

function estimateTokensFromChars(chars: number): number {
	return Math.max(0, Math.ceil(chars / 4));
}

function jsonLength(value: unknown): number {
	if (typeof value === "string") return value.length;
	try {
		return JSON.stringify(value ?? {}).length;
	} catch {
		return String(value).length;
	}
}

/** Characters attributable to one assistant content block (text, thinking, or tool call). */
export function charsFromContentBlock(block: unknown): number {
	if (!isRecord(block)) return 0;

	switch (block.type) {
		case "text":
			return typeof block.text === "string" ? block.text.length : 0;
		case "thinking":
			return typeof block.thinking === "string" ? block.thinking.length : 0;
		case "toolCall": {
			const name = typeof block.name === "string" ? block.name : "";
			return name.length + jsonLength(block.arguments);
		}
		default:
			return 0;
	}
}

/** Full assistant payload size: visible text, thinking, and tool-call arguments. */
export function charsFromMessage(message: unknown): number {
	if (!isRecord(message) || !Array.isArray(message.content)) return 0;
	return message.content.reduce<number>((total, block) => total + charsFromContentBlock(block), 0);
}

/** Stream delta characters for text, thinking, and tool-call JSON chunks. */
export function deltaCharsFromEvent(event: unknown): number {
	if (!isRecord(event) || typeof event.type !== "string") return 0;
	if (!event.type.endsWith("_delta")) return 0;
	return typeof event.delta === "string" ? event.delta.length : 0;
}

export function isOutputEvent(event: unknown): boolean {
	if (!isRecord(event) || typeof event.type !== "string") return false;
	return OUTPUT_EVENT_TYPES.has(event.type);
}

/**
 * Prefer provider usage. When a provider reports reasoning outside `output`
 * (reasoning > output), add them. Fall back to content/stream char estimates so
 * thinking and tool calls still count when usage is missing.
 */
export function outputTokensFromMessage(message: unknown, fallbackChars: number): number {
	const usage = isRecord(message) && isRecord(message.usage) ? message.usage : undefined;
	const output = typeof usage?.output === "number" && Number.isFinite(usage.output) ? usage.output : undefined;
	const reasoning =
		typeof usage?.reasoning === "number" && Number.isFinite(usage.reasoning) ? usage.reasoning : undefined;

	if (output !== undefined && output > 0) {
		// Most providers nest reasoning inside output; a few report them separately.
		return reasoning !== undefined && reasoning > output ? output + reasoning : output;
	}
	if (reasoning !== undefined && reasoning > 0) return reasoning;

	const contentChars = Math.max(charsFromMessage(message), fallbackChars);
	return estimateTokensFromChars(contentChars);
}

export function isFinalAssistantMessage(message: unknown): boolean {
	if (!isRecord(message)) return false;
	return message.role === "assistant" && message.stopReason !== "error" && message.stopReason !== "aborted";
}
