import { noteDecision, type NoteDecision } from "./decision.ts";

export const REVIEW_SHORTCUT = "ctrl+;";
export interface Warning { id: string; note: string; source: string; decision?: NoteDecision }
const clean = (text: string) => text.replace(/[\u0000-\u001f\u007f-\u009f]/g, " ").trim().slice(0, 600);
export class WarningInbox {
	readonly pending: Warning[] = [];
	private selected = "";
	get current() { return this.pending.find((warning) => warning.id === this.selected) ?? this.pending[0]; }
	get index() { return Math.max(0, this.pending.findIndex((warning) => warning.id === this.current?.id)); }
	add(value: unknown) {
		const data = value as Partial<Warning> | undefined;
		if (!data || typeof data.note !== "string" || !clean(data.note) || typeof data.id !== "string" || !data.id ||
			this.pending.some((warning) => warning.id === data.id)) return;
		this.pending.push({ id: data.id, note: clean(data.note), source: typeof data.source === "string" ? data.source.slice(-24_000) : "",
			decision: noteDecision(data.decision) });
		if (!this.selected) this.selected = data.id;
	}
	acknowledge(id: string) {
		const index = this.pending.findIndex((warning) => warning.id === id);
		if (index < 0) return;
		const selected = this.current?.id;
		this.pending.splice(index, 1);
		if (selected === id) this.selected = this.pending[Math.min(index, this.pending.length - 1)]?.id ?? "";
	}
	move(delta: number) {
		if (this.pending.length) this.selected = this.pending[(this.index + this.pending.length + delta) % this.pending.length].id;
	}
	static restore(entries: Iterable<{ type: string; id?: string; customType?: string; data?: unknown }>) {
		const inbox = new WarningInbox();
		let review: NoteDecision | undefined, index = 0;
		for (const entry of entries) {
			index++;
			if (entry.type !== "custom") continue;
			const data = entry.data as any;
			if (entry.customType === "you-should-know-review") review = noteDecision(data);
			if (entry.customType === "you-should-know-acknowledged" && typeof data?.id === "string") inbox.acknowledge(data.id);
			if (entry.customType !== "you-should-know-note" || typeof data?.note !== "string") continue;
			// Before the inbox, note entries were replaceable snapshots. Preserve their last visible state,
			// rather than resurrecting warnings that the old implementation already cleared.
			if (data.queued !== true) { inbox.pending.splice(0); inbox.selected = ""; }
			inbox.add({ ...data, id: typeof data.id === "string" && data.id ? data.id : `legacy:${entry.id ?? index}`,
				decision: noteDecision(data.decision) ?? (data.queued === true ? undefined : review) });
		}
		return inbox;
	}
}
