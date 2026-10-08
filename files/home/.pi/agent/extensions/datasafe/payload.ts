import { Type, type Static } from "typebox";
import { WireValue } from "../shared/wire_value.ts";

export const RequestPayload = Type.Object({
	model: Type.Optional(Type.String()),
	provider: Type.Optional(Type.Record(Type.String(), WireValue)),
	providerOptions: Type.Optional(
		Type.Intersect([
			Type.Record(Type.String(), WireValue),
			Type.Object({ gateway: Type.Optional(Type.Record(Type.String(), WireValue)) }),
		]),
	),
});

export type RequestPayload = Static<typeof RequestPayload>;
