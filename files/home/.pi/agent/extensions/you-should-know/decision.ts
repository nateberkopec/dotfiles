import type { Decision } from "./jev.ts";

export type NoteDecision = Pick<Decision, "confidence" | "category">;
// VER remains readable when restoring historical warnings; new reviews never produce it.
const categories: Record<string, string> = { wrong_result: "RESULT", cost: "COST", wasted_work: "WORK",
	verification: "VER", data_loss: "LOSS", security: "SEC", none: "NONE" };
export function noteDecision(value: unknown): NoteDecision | undefined {
	const data = value as NoteDecision | undefined;
	return data && Number.isFinite(data.confidence) && data.confidence >= 0 && data.confidence <= 1 &&
		Object.hasOwn(categories, data.category) ? { confidence: data.confidence, category: data.category } : undefined;
}
export function noteLabel(decision?: NoteDecision): string {
	const data = noteDecision(decision);
	return data ? `YSK (${Math.round(data.confidence * 100)}%|${categories[data.category]}):` : "YSK:";
}
