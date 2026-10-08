import { Type } from "typebox";

const Json = Type.Cyclic(
	{
		Value: Type.Union([
			Type.Null(),
			Type.Boolean(),
			Type.Number(),
			Type.String(),
			Type.Array(Type.Ref("Value")),
			Type.Record(Type.String(), Type.Ref("Value")),
		]),
	},
	"Value",
);

const Text = Type.Object({
	type: Type.Literal("text"),
	text: Type.String(),
	textSignature: Type.Optional(Type.String()),
});

const Image = Type.Object({ type: Type.Literal("image"), data: Type.String(), mimeType: Type.String() });

const Thinking = Type.Object({
	type: Type.Literal("thinking"),
	thinking: Type.String(),
	thinkingSignature: Type.Optional(Type.String()),
	redacted: Type.Optional(Type.Boolean()),
});

const ToolCall = Type.Object({
	type: Type.Literal("toolCall"),
	id: Type.String(),
	name: Type.String(),
	arguments: Type.Record(Type.String(), Json),
	thoughtSignature: Type.Optional(Type.String()),
	namespace: Type.Optional(Type.String()),
});

const Usage = Type.Object({
	input: Type.Number(),
	output: Type.Number(),
	cacheRead: Type.Number(),
	cacheWrite: Type.Number(),
	cacheWrite1h: Type.Optional(Type.Number()),
	reasoning: Type.Optional(Type.Number()),
	totalTokens: Type.Number(),
	cost: Type.Object({
		input: Type.Number(),
		output: Type.Number(),
		cacheRead: Type.Number(),
		cacheWrite: Type.Number(),
		total: Type.Number(),
	}),
});

// Preserve SDK system/tool declarations as well as conversation content when replaying a side chat.
export const ChatMessage = Type.Union([
	Type.Object({
		role: Type.Literal("system"),
		content: Type.Union([Type.String(), Type.Array(Text)]),
		timestamp: Type.Number(),
		sections: Type.Optional(Type.Record(Type.String(), Type.Union([Type.String(), Type.Null()]))),
		toolsAdded: Type.Optional(
			Type.Array(
				Type.Object({ name: Type.String(), description: Type.String(), parameters: Type.Record(Type.String(), Json) }),
			),
		),
		toolsRemoved: Type.Optional(Type.Array(Type.Object({ name: Type.String() }))),
	}),
	Type.Object({
		role: Type.Literal("user"),
		content: Type.Union([Type.String(), Type.Array(Type.Union([Text, Image]))]),
		timestamp: Type.Number(),
	}),
	Type.Object({
		role: Type.Literal("assistant"),
		content: Type.Array(Type.Union([Text, Thinking, ToolCall])),
		api: Type.String(),
		provider: Type.String(),
		model: Type.String(),
		usage: Usage,
		stopReason: Type.Union(
			(["pending", "stop", "length", "toolUse", "error", "aborted", "deferred"] as const).map((reason) =>
				Type.Literal(reason),
			),
		),
		errorMessage: Type.Optional(Type.String()),
		timestamp: Type.Number(),
	}),
	Type.Object({
		role: Type.Literal("toolResult"),
		toolCallId: Type.String(),
		toolName: Type.String(),
		content: Type.Array(Type.Union([Text, Image])),
		details: Type.Optional(Json),
		isError: Type.Boolean(),
		timestamp: Type.Number(),
	}),
]);
