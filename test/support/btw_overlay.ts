import assert from "node:assert/strict";
import { stripVTControlCharacters } from "node:util";
import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { visibleWidth } from "@earendil-works/pi-tui";
import { openOverlay } from "../../files/home/.pi/agent/extensions/btw/overlay.ts";

export default function overlayFixture(pi: ExtensionAPI) {
	pi.registerCommand("overlay-render-test", {
		description: "Exercise the real shared overlay renderer without network or an interactive terminal.",
		handler: async (_args, ctx) => {
			let cases = 0;
			const failures: string[] = [];
			for (const text of ["**YSK:** Verify the backup first.", "**You:** Explain.\n\n**Assistant:** Short answer.\n\nAnother paragraph.",
				"**Assistant:** 日本語 🙂 café\n\n```sh\necho dry-run\n```\n\n" + "A long wrapped response. ".repeat(30)]) {
				const fake = { ...ctx, ui: { ...ctx.ui, custom: async (factory) => {
					try {
					const component = factory({ requestRender() {} }, ctx.ui.theme, { matches: () => false }, () => {});
					for (const width of [3, 12, 43, 90, 118]) {
						const rows = component.render(width);
						for (const [index, row] of rows.entries()) {
							assert.equal(visibleWidth(row), width, `row ${index} must fully cover its overlay width ${width}`);
							const plain = stripVTControlCharacters(row);
							if (index > 0 && index < rows.length - 1) {
								assert.ok(plain.startsWith("│") && plain.endsWith("│"), `body row ${index} needs both borders: ${plain}`);
							}
						}
						cases++;
					}
					} catch (error) { failures.push((error as Error).message); }
				} } } as ExtensionCommandContext;
				openOverlay(fake, { title: "YSK · Luna · no tools", text: () => text, status: () => "Ready", submit() {}, cancel() {} });
				// openOverlay intentionally sanitizes UI errors; assert that each render completed too.
			}
			pi.appendEntry("btw-overlay-proof", { cases, failures });
		},
	});
}
