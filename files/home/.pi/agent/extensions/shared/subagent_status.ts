import { Type } from "typebox";

export const FleetStatusReply = Type.Object({
	version: Type.Literal(1),
	requestId: Type.String(),
	success: Type.Literal(true),
	data: Type.Object({
		fleet: Type.Object({
			version: Type.Literal(1),
			totalActive: Type.Integer({ minimum: 0, maximum: Number.MAX_SAFE_INTEGER }),
		}),
	}),
});
