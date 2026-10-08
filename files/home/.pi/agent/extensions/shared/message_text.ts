import type { Message } from "@earendil-works/pi-ai/compat";
import { Type } from "typebox";
import { Value } from "typebox/value";

const TextBlock = Type.Object({ type: Type.Literal("text"), text: Type.String() });

export function messageText(content: Message["content"] | undefined): string {
	if (Value.Check(Type.String(), content)) return content;

	if (!Array.isArray(content)) return "";

	return content.flatMap((block) => (Value.Check(TextBlock, block) && block.text ? [block.text] : [])).join("\n");
}
