import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { Message } from "@earendil-works/pi-ai/compat";
import { messageText } from "../shared/message_text.ts";

type TextMessage = Partial<Pick<Message, "content">>;

export function textOf(message: TextMessage): string {
	return messageText(message.content);
}

export function transcript(ctx: ExtensionContext, assistant?: TextMessage): string {
	const messages = ctx.sessionManager.getBranch().flatMap((entry) => {
		if (entry.type !== "message") return [];
		const message = entry.message;

		return message.role === "user" || message.role === "assistant" || message.role === "toolResult" ? [message] : [];
	});

	const lines = messages.flatMap((message) => (textOf(message) ? [`${message.role}: ${textOf(message)}`] : []));
	// message_end precedes persistence; avoid duplicating an already-persisted assistant at agent_end.
	const text = assistant && textOf(assistant);

	if (text && (messages.at(-1)?.role !== "assistant" || textOf(messages.at(-1)!) !== text))
		lines.push(`assistant: ${text}`);

	return lines.join("\n\n").trim().slice(-24_000);
}
