import { noteDecision, NoteDecision } from "./decision.ts";
import { Type } from "typebox";
import { Value } from "typebox/value";
import { WireValue } from "../shared/wire_value.ts";

const StoredWarning = Type.Object({
	note: Type.String(),
	id: Type.Optional(WireValue),
	source: Type.Optional(WireValue),
	decision: Type.Optional(WireValue),
	queued: Type.Optional(WireValue),
});

const WarningIdentity = Type.Object({
	id: Type.String(),
	note: Type.String(),
	source: Type.Optional(WireValue),
	decision: Type.Optional(WireValue),
});

export const REVIEW_SHORTCUT = "ctrl+;";

export interface Warning {
	id: string;
	note: string;
	source: string;
	decision?: NoteDecision;
}

const clean = (text: string) =>
	text
		.replace(/\p{Cc}/gu, " ")
		.trim()
		.slice(0, 600);

export class WarningInbox {
	readonly pending: Warning[] = [];
	private selected = "";
	get current() {
		return this.pending.find((warning) => warning.id === this.selected) ?? this.pending[0];
	}
	get index() {
		return Math.max(
			0,
			this.pending.findIndex((warning) => warning.id === this.current?.id),
		);
	}
	add(data: Partial<Warning> | undefined) {
		if (
			!Value.Check(WarningIdentity, data) ||
			!clean(data.note) ||
			!data.id ||
			this.pending.some((warning) => warning.id === data.id)
		)
			return;
		this.pending.push({
			id: data.id,
			note: clean(data.note),
			source: Value.Check(Type.String(), data.source) ? data.source.slice(-24_000) : "",
			decision: Value.Check(NoteDecision, data.decision) ? noteDecision(data.decision) : undefined,
		});

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
		if (this.pending.length)
			this.selected = this.pending[(this.index + this.pending.length + delta) % this.pending.length].id;
	}
	static restore(entries: Iterable<{ type: string; id?: string; customType?: string; data?: unknown }>) {
		const inbox = new WarningInbox();

		let review: NoteDecision | undefined,
			index = 0;

		for (const entry of entries) {
			index++;

			if (entry.type !== "custom") continue;
			const data = entry.data;

			if (entry.customType === "you-should-know-review")
				review = Value.Check(NoteDecision, data) ? noteDecision(data) : undefined;

			if (entry.customType === "you-should-know-acknowledged" && Value.Check(Type.Object({ id: Type.String() }), data))
				inbox.acknowledge(data.id);

			if (entry.customType !== "you-should-know-note" || !Value.Check(StoredWarning, data)) continue;

			// Before the inbox, note entries were replaceable snapshots. Preserve their last visible state,
			// rather than resurrecting warnings that the old implementation already cleared.
			if (data.queued !== true) {
				inbox.pending.splice(0);
				inbox.selected = "";
			}

			inbox.add({
				...data,
				id: Value.Check(Type.String(), data.id) && data.id ? data.id : `legacy:${entry.id ?? index}`,
				source: Value.Check(Type.String(), data.source) ? data.source : "",
				decision:
					(Value.Check(NoteDecision, data.decision) ? noteDecision(data.decision) : undefined) ??
					(data.queued === true ? undefined : review),
			});
		}

		return inbox;
	}
}
