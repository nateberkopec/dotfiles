import type { Decision } from "./jev.ts";
import { Type } from "typebox";
import { Value } from "typebox/value";

export type NoteDecision = Pick<Decision, "confidence" | "category">;

// VER remains readable when restoring historical warnings; new reviews never produce it.
const categories = {
	wrong_result: "RESULT",
	cost: "COST",
	wasted_work: "WORK",
	verification: "VER",
	data_loss: "LOSS",
	security: "SEC",
	none: "NONE",
} as const;

export const NoteDecision = Type.Object({
	confidence: Type.Number({ minimum: 0, maximum: 1 }),
	category: Type.Union(Object.keys(categories).map((key) => Type.Literal(key))),
});

export function noteDecision(value: NoteDecision | undefined): NoteDecision | undefined {
	return Value.Check(NoteDecision, value) ? { confidence: value.confidence, category: value.category } : undefined;
}

export function noteLabel(decision?: NoteDecision): string {
	const data = noteDecision(decision);

	const label = Object.entries(categories).find(([category]) => category === data?.category)?.[1];

	return data && label ? `YSK (${Math.round(data.confidence * 100)}%|${label}):` : "YSK:";
}
