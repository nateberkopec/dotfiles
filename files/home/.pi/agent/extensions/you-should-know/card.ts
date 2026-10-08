import { matchesKey, truncateToWidth, wrapTextWithAnsi } from "@earendil-works/pi-tui";
import type { Theme } from "@earendil-works/pi-coding-agent";
import { noteLabel, type NoteDecision } from "./decision.ts";
import { REVIEW_SHORTCUT, type WarningInbox, type Warning } from "./inbox.ts";

export function preview(note: string, decision: NoteDecision | undefined, count: number, theme: Theme, width: number) {
	const label = theme.fg("accent", theme.bold(noteLabel(decision)));
	const full = wrapTextWithAnsi(`${label} ${note}`, Math.max(1, width));
	const lines = full.slice(0, 2);

	if (full.length > 2) lines[1] = truncateToWidth(lines[1], Math.max(0, width - 1), "") + "…";

	if (count > 1) lines.push(theme.fg("dim", `${count - 1} more waiting`));

	return lines.map((line) => truncateToWidth(line, Math.max(0, width), ""));
}

export type CardResult = { details: Warning } | undefined;

export function warningCard(
	inbox: WarningInbox,
	theme: Theme,
	refresh: () => void,
	done: (result: CardResult) => void,
	acknowledge: (warning: Warning) => void,
	terminalRows = () => process.stdout.rows ?? 30,
) {
	let offset = 0,
		maximum = 0,
		action = 0;

	const labels = ["(A)cknowledge", "(D)etails", "(B)ack to editor"];

	return {
		invalidate() {},
		handleInput(data: string) {
			if (matchesKey(data, "escape") || matchesKey(data, REVIEW_SHORTCUT) || matchesKey(data, "ctrl+c")) {
				done(undefined);

				return;
			}

			if (matchesKey(data, "right")) action = (action + 1) % labels.length;

			if (matchesKey(data, "left")) action = (action + labels.length - 1) % labels.length;

			if (matchesKey(data, "tab") || matchesKey(data, "shift+tab")) {
				inbox.move(matchesKey(data, "tab") ? 1 : -1);
				offset = 0;
			}

			if (matchesKey(data, "up")) offset = Math.max(0, offset - 1);

			if (matchesKey(data, "down")) offset = Math.min(maximum, offset + 1);

			const mnemonic = (["a", "d", "b"] as const).findIndex(
				(key) => matchesKey(data, key) || matchesKey(data, `shift+${key}`),
			);

			if (mnemonic !== -1) action = mnemonic;

			if (matchesKey(data, "enter") || mnemonic !== -1) {
				const warning = inbox.current;

				if (!warning || action === 2) {
					done(undefined);

					return;
				}

				if (action === 1) {
					done({ details: { ...warning } });

					return;
				}

				acknowledge(warning);
				offset = 0;

				if (!inbox.current) {
					done(undefined);

					return;
				}
			}

			refresh();
		},
		render(width: number) {
			const columns = Math.max(1, width),
				warning = inbox.current;

			const wrapped = wrapTextWithAnsi(warning?.note ?? "All acknowledged. Enter returns to your draft.", columns);
			const height = Math.max(1, Math.min(8, terminalRows() - 10));
			maximum = Math.max(0, wrapped.length - height);
			offset = Math.min(offset, maximum);

			const buttons = labels
				.map((label, i) =>
					i === action ? theme.fg("accent", theme.bold(`[ ${label} ]`)) : theme.fg("dim", `  ${label}  `),
				)
				.join("  ");

			return [
				theme.fg("accent", theme.bold(`${noteLabel(warning?.decision)} ${inbox.index + 1} of ${inbox.pending.length}`)),
				...wrapped.slice(offset, offset + height),
				"",
				...wrapTextWithAnsi(buttons, columns),
				theme.fg("dim", `←→ actions · Enter choose · Tab warnings · A/D/B · Esc back${maximum ? " · ↑↓ scroll" : ""}`),
			].map((line) => truncateToWidth(line, Math.max(0, width), ""));
		},
	};
}
