export function isDeltaEvent(event: unknown): event is { type: string; delta?: string } {
	if (!event || typeof event !== "object") return false;
	const type = (event as { type?: unknown }).type;
	return typeof type === "string" && type.endsWith("_delta");
}

export function isOutputEvent(event: unknown): boolean {
	if (!event || typeof event !== "object") return false;
	const type = (event as { type?: unknown }).type;
	return (
		type === "text_start" ||
		type === "text_delta" ||
		type === "text_end" ||
		type === "thinking_start" ||
		type === "thinking_delta" ||
		type === "thinking_end" ||
		type === "toolcall_start" ||
		type === "toolcall_delta" ||
		type === "toolcall_end"
	);
}

export function outputTokensFromMessage(message: unknown, fallbackChars: number): number {
	const usage = (message as { usage?: { output?: unknown } } | undefined)?.usage;
	if (typeof usage?.output === "number" && usage.output > 0) return usage.output;
	return Math.max(0, Math.ceil(fallbackChars / 4));
}

export function isFinalAssistantMessage(message: unknown): boolean {
	if (!message || typeof message !== "object") return false;
	const msg = message as { role?: unknown; stopReason?: unknown };
	return msg.role === "assistant" && msg.stopReason !== "error" && msg.stopReason !== "aborted";
}
