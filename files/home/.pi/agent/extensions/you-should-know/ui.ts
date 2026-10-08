import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { UsageLedger } from "./usage.ts";
import { noteLabel, type NoteDecision } from "./decision.ts";
import type { WarningInbox, Warning } from "./inbox.ts";

export { noteDecision, noteLabel, type NoteDecision } from "./decision.ts";

export const KEY = "you-should-know";

export class ObserverUI {
	private pulse: ReturnType<typeof setInterval> | undefined;
	private frame = 0;
	private ctx: ExtensionContext;
	private ledger: UsageLedger;
	private closeFocused?: () => void;
	private refreshFocused?: () => void;
	private focused = false;
	private cardEpoch = 0;
	constructor(ctx: ExtensionContext, ledger: UsageLedger) {
		this.ctx = ctx;
		this.ledger = ledger;
	}
	footer() {
		if (this.ctx.mode !== "tui") return;
		this.ctx.ui.setWidget(
			`${KEY}-usage`,
			(_tui, theme) => ({
				// Fixed labels, numbers and indicator each occupy one terminal column; no padding.
				render: (width) => [
					theme.fg(
						"dim",
						`${this.pulse ? "|/-\\"[this.frame % 4] : "·"} ${this.ledger.footer()}`.slice(0, Math.max(0, width)),
					),
				],
				invalidate() {},
			}),
			{ placement: "belowEditor" },
		);
	}
	stop() {
		clearInterval(this.pulse);
		this.pulse = undefined;
	}
	waiting(active: boolean) {
		this.stop();

		if (active && this.ctx.mode === "tui") {
			this.frame = 0;
			this.pulse = setInterval(() => {
				this.frame = (this.frame + 1) % 12;
				this.footer();
			}, 100);
		}

		this.footer();
	}
	closeCard() {
		this.cardEpoch++;
		this.closeFocused?.();
	}
	async review(ctx: ExtensionContext, inbox: WarningInbox, acknowledge: (warning: Warning) => void) {
		if (this.focused || ctx.mode !== "tui" || !inbox.current) return;
		const version = this.cardEpoch;
		this.focused = true;

		try {
			const { warningCard } = await import("./card.ts");

			if (version !== this.cardEpoch) return;
			ctx.ui.setWidget(KEY, undefined);

			return await ctx.ui.custom<import("./card.ts").CardResult>((tui, theme, _keys, done) => {
				this.closeFocused = () => done(undefined);
				this.refreshFocused = () => tui.requestRender();

				return warningCard(inbox, theme, this.refreshFocused, done, acknowledge);
			});
		} finally {
			this.focused = false;
			this.closeFocused = undefined;
			this.refreshFocused = undefined;
		}
	}
	async note(note: string, current: () => boolean, explaining = false, decision?: NoteDecision, count = 1) {
		if (this.ctx.mode !== "tui" || !current()) return;
		this.refreshFocused?.();

		if (this.focused || !note) {
			this.ctx.ui.setWidget(KEY, undefined);

			return;
		}

		const { Text } = await import("@earendil-works/pi-tui"),
			{ preview } = await import("./card.ts");

		if (current() && !this.focused)
			this.ctx.ui.setWidget(KEY, (_tui, theme) => ({
				render: (width) =>
					explaining
						? new Text(
								`${theme.fg("accent", theme.bold(noteLabel()))} ${theme.fg(
									"dim",
									`${note}${".".repeat(1 + Math.floor(this.frame / 4))}`,
								)}`,
								0,
								0,
							).render(width)
						: preview(note, decision, count, theme, width),
				invalidate() {},
			}));
	}
}
