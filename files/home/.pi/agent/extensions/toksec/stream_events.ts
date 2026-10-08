import type { AssistantMessage, AssistantMessageEvent, ToolCall } from "@earendil-works/pi-ai";
import { Type } from "typebox";
import { Value } from "typebox/value";

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

const TextBlock = Type.Object({ type: Type.Literal("text"), text: Type.String() });

const ThinkingBlock = Type.Object({ type: Type.Literal("thinking"), thinking: Type.String() });

const ToolBlock = Type.Object({ type: Type.Literal("toolCall") });

const Delta = Type.Object({ type: Type.String(), delta: Type.String() });

const FinalAssistant = Type.Object({ role: Type.Literal("assistant"), stopReason: Type.Optional(Type.String()) });

function estimateTokensFromChars(chars: number): number {
	return Math.max(0, Math.ceil(chars / 4));
}

function jsonLength(value: ToolCall["arguments"] | string | undefined): number {
	if (Value.Check(Type.String(), value)) return value.length;

	try {
		return JSON.stringify(value ?? {}).length;
	} catch {
		return String(value).length;
	}
}

/** Characters attributable to one assistant content block (text, thinking, or tool call). */
export function charsFromContentBlock(block: AssistantMessage["content"][number] | undefined): number {
	if (Value.Check(TextBlock, block)) return block.text.length;

	if (Value.Check(ThinkingBlock, block)) return block.thinking.length;

	if (!Value.Check(ToolBlock, block)) return 0;
	const name = Value.Check(Type.Object({ name: Type.String() }), block) ? block.name : "";

	return name.length + jsonLength(block.arguments);
}

/** Full assistant payload size: visible text, thinking, and tool-call arguments. */
export function charsFromMessage(message: Pick<AssistantMessage, "content"> | undefined): number {
	if (!message || !Array.isArray(message.content)) return 0;

	return message.content.reduce<number>((total, block) => total + charsFromContentBlock(block), 0);
}

/** Stream delta characters for text, thinking, and tool-call JSON chunks. */
export function deltaCharsFromEvent(event: AssistantMessageEvent | undefined): number {
	if (!Value.Check(Delta, event) || !event.type.endsWith("_delta")) return 0;

	return event.delta.length;
}

export function isOutputEvent(event: AssistantMessageEvent | undefined): boolean {
	return !!event && OUTPUT_EVENT_TYPES.has(event.type);
}

/** Prefer provider usage; estimate from content only when usage is missing. */
export function outputTokensFromMessage(
	message: Pick<AssistantMessage, "content" | "usage"> | undefined,
	fallbackChars: number,
): number {
	const usage = message?.usage;
	const output = Value.Check(Type.Number(), usage?.output) ? usage.output : undefined;
	const reasoning = Value.Check(Type.Number(), usage?.reasoning) ? usage.reasoning : undefined;

	if (output !== undefined && output > 0) {
		// Most providers nest reasoning inside output; a few report them separately.
		return reasoning !== undefined && reasoning > output ? output + reasoning : output;
	}

	if (reasoning !== undefined && reasoning > 0) return reasoning;

	return estimateTokensFromChars(Math.max(charsFromMessage(message), fallbackChars));
}

export function isFinalAssistantMessage(message: unknown): message is Pick<AssistantMessage, "role"> {
	return Value.Check(FinalAssistant, message) && message.stopReason !== "error" && message.stopReason !== "aborted";
}
