import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { UsageLedger } from "./usage.ts";

export const KEY = "you-should-know";
export class ObserverUI {
	private pulse: ReturnType<typeof setInterval> | undefined;
	private frame = 0;
	private ctx: ExtensionContext;
	private ledger: UsageLedger;
	constructor(ctx: ExtensionContext, ledger: UsageLedger) { this.ctx = ctx; this.ledger = ledger; }
	footer() {
		if (this.ctx.mode !== "tui") return;
		this.ctx.ui.setWidget(`${KEY}-usage`, (_tui, theme) => ({
			// Fixed labels, numbers and indicator each occupy one terminal column; no padding.
			render: (width) => [theme.fg("dim", `${this.pulse ? "|/-\\"[this.frame % 4] : "·"} ${this.ledger.footer()}`.slice(0, Math.max(0, width)))],
			invalidate() {},
		}), { placement: "belowEditor" });
	}
	stop() { clearInterval(this.pulse); this.pulse = undefined; }
	waiting(active: boolean) {
		this.stop();
		if (active && this.ctx.mode === "tui") {
			this.frame = 0;
			this.pulse = setInterval(() => { this.frame = (this.frame + 1) % 12; this.footer(); }, 100);
		}
		this.footer();
	}
	async note(note: string, current: () => boolean, explaining = false) {
		if (this.ctx.mode !== "tui" || !current()) return;
		if (!note) { this.ctx.ui.setWidget(KEY, undefined); return; }
		const { Text } = await import("@earendil-works/pi-tui");
		if (current()) this.ctx.ui.setWidget(KEY, (_tui, theme) => ({
			render: (width) => new Text(`${theme.fg("accent", theme.bold("YSK:"))} ${explaining
				? theme.fg("dim", `${note}${".".repeat(1 + Math.floor(this.frame / 4))}`) : note}`, 0, 0).render(width),
			invalidate() {},
		}));
	}
}
