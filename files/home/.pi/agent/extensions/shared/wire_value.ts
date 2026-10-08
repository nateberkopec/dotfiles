import { Type, type Static } from "typebox";

// SDK payloads may contain undefined fields before JSON serialization omits them.
export const WireValue = Type.Cyclic(
	{
		Value: Type.Union([
			Type.Null(),
			Type.Undefined(),
			Type.Boolean(),
			Type.Number(),
			Type.String(),
			Type.Array(Type.Ref("Value")),
			Type.Record(Type.String(), Type.Ref("Value")),
		]),
	},
	"Value",
);

export type WireValue = Static<typeof WireValue>;
