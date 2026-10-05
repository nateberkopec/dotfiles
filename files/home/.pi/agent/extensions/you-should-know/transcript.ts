import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

export function textOf(message: { content?: unknown }): string {
	if (typeof message.content === "string") return message.content;
	if (!Array.isArray(message.content)) return "";
	return message.content.filter((block) => block.type === "text" && typeof block.text === "string")
		.map((block) => block.text).join("\n");
}
export function transcript(ctx: ExtensionContext, assistant?: { content?: unknown }): string {
	const messages = ctx.sessionManager.getBranch().flatMap((entry) => {
		if (entry.type !== "message") return [];
		const message = entry.message;
		return message.role === "user" || message.role === "assistant" || message.role === "toolResult" ? [message] : [];
	});
	const lines = messages.flatMap((message) => textOf(message) ? [`${message.role}: ${textOf(message)}`] : []);
	// message_end precedes persistence; avoid duplicating an already-persisted assistant at agent_end.
	const text = assistant && textOf(assistant);
	if (text && (messages.at(-1)?.role !== "assistant" || textOf(messages.at(-1)!) !== text)) lines.push(`assistant: ${text}`);
	return lines.join("\n\n").trim().slice(-24_000);
}
