// Adapted from Armin Ronacher's agent-stuff/extensions/btw.ts at 0865c849befd2021490679f96a8dee58c84ac857.
// Modified: configurable title, narrow sizing, native cursor handling, close without a dialog.
// Apache-2.0; see LICENSE in this directory.
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Input, Markdown, truncateToWidth, visibleWidth, type Focusable } from "@earendil-works/pi-tui";
import { getMarkdownTheme } from "@earendil-works/pi-coding-agent";

export interface ChatView {
	title: string;
	text: () => string;
	status: () => string;
	submit: (question: string) => void;
	cancel: () => void;
}

export function openOverlay(ctx: ExtensionContext, view: ChatView) {
	let refresh = () => {},
		close = () => {},
		closed = false;

	void ctx.ui
		.custom<void>(
			(tui, theme, keys, done) => {
				const input = new Input();

				const finish = () => {
					closed = true;
					done();
				};

				input.onSubmit = (text) => {
					if (text.trim()) {
						input.setValue("");
						view.submit(text.trim());
					}
				};

				input.onEscape = () => {
					view.cancel();
					finish();
				};

				const component: Focusable & {
					render: (width: number) => string[];
					invalidate: () => void;
					handleInput: (data: string) => void;
				} = {
					get focused() {
						return input.focused;
					},
					set focused(value) {
						input.focused = value;
					},
					handleInput(data) {
						if (keys.matches(data, "tui.select.cancel")) {
							view.cancel();
							finish();
						} else input.handleInput(data);
					},
					render(width) {
						if (width < 3) return [truncateToWidth(view.title, Math.max(0, width), "")];

						const inner = Math.max(1, width - 2),
							border = (edge: "top" | "bottom") =>
								theme.fg(
									"borderMuted",
									`${edge === "top" ? "┌" : "└"}${"─".repeat(inner)}${edge === "top" ? "┐" : "┘"}`,
								);

						const line = (text: string) => {
							const clipped = truncateToWidth(text, inner, "");

							return `${theme.fg("borderMuted", "│")}${clipped}${" ".repeat(Math.max(0, inner - visibleWidth(clipped)))}${theme.fg("borderMuted", "│")}`;
						};

						const height = Math.max(1, Math.min(18, (process.stdout.rows ?? 30) - 10));
						const transcript = new Markdown(view.text(), 0, 0, getMarkdownTheme()).render(inner).slice(-height);

						return [
							border("top"),
							line(theme.fg("accent", theme.bold(view.title))),
							...transcript.map(line),
							line(theme.fg("dim", view.status())),
							line(input.render(inner)[0] ?? ""),
							line(theme.fg("dim", "Enter: send · Esc: close")),
							border("bottom"),
						];
					},
					invalidate() {
						input.invalidate();
					},
				};

				component.focused = true;
				refresh = () => tui.requestRender();
				close = () => {
					view.cancel();
					finish();
				};

				if (closed) done();

				return component;
			},
			{ overlay: true, overlayOptions: { width: "90%", maxHeight: "90%", anchor: "top-center", margin: 1 } },
		)
		.catch(() => {
			closed = true;
			view.cancel();
			ctx.ui.notify("Side-chat UI failed.", "warning");
		});

	return {
		refresh: () => refresh(),
		close: () => {
			closed = true;
			close();
		},
		get closed() {
			return closed;
		},
	};
}
