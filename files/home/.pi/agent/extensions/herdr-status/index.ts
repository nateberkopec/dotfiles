import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { subagentsRunning } from "../notify/readiness.ts";
import { createReporter } from "./reporter.ts";

import { Type } from "typebox";
import { Value } from "typebox/value";
import { WireValue } from "../shared/wire_value.ts";

const Overlay = Type.Object({ active: Type.Boolean(), label: Type.Optional(WireValue) });

export default function (pi: ExtensionAPI) {
	const env = process.env;

	if (env.HERDR_ENV !== "1" || !env.HERDR_SOCKET_PATH || !env.HERDR_PANE_ID || env.PI_SUBAGENT_CHILD === "1") return;
	const reporter = createReporter(env);
	let session: ExtensionContext | undefined;
	let active = false;
	let busyCount = 0;
	let restoredBusy = false;
	let blockedCount = 0;
	let blockedLabel: string | undefined;
	let revision = 0;
	let last: string | undefined;

	function publish(force = false) {
		if (!session) return;
		const message = blockedCount ? blockedLabel : undefined;
		const state = blockedCount ? "blocked" : active || busyCount || restoredBusy ? "working" : "idle";
		const key = JSON.stringify([state, message]);

		if (!force && key === last) return;
		last = key;
		reporter.state(session, state, message);
	}

	async function reconcile(ctx: ExtensionContext) {
		const current = ++revision;
		const busy = await subagentsRunning(pi);

		if (session !== ctx || current !== revision) return;
		restoredBusy = busy;
	}

	async function start(event: { reason?: string }, ctx: ExtensionContext) {
		revision++;
		reporter.clear();
		session = ctx.mode === "tui" ? ctx : undefined;
		active = !ctx.isIdle();
		busyCount = blockedCount = 0;
		restoredBusy = false;
		blockedLabel = last = undefined;

		if (!session) return;
		await reporter.session(ctx, event.reason);

		if (session !== ctx) return;
		await reconcile(ctx);
		publish(true);
	}

	pi.on("session_start", start);
	pi.on("session_tree", (_event, ctx) => start({}, ctx));
	pi.on("agent_start", (_event, ctx) => {
		if (!session) return;
		session = ctx;
		active = true;
		void reporter.session(ctx);
		publish();
	});
	pi.on("agent_settled", async (_event, ctx) => {
		if (!session || !ctx.isIdle()) return;
		session = ctx;
		active = false;
		await reconcile(ctx);
		publish();
	});

	const subscriptions = ["busy", "blocked"].map((kind) =>
		pi.events.on(`herdr:${kind}`, (value) => {
			if (!session || !Value.Check(Overlay, value)) return;
			const data = { active: value.active, label: Value.Check(Type.String(), value.label) ? value.label : undefined };

			if (kind === "busy") {
				revision++;
				restoredBusy = false;
				busyCount = Math.max(0, busyCount + (data.active ? 1 : -1));
			} else {
				blockedCount = Math.max(0, blockedCount + (data.active ? 1 : -1));

				if (data.active) blockedLabel = data.label;
				else if (!blockedCount) blockedLabel = undefined;
			}

			publish();
		}),
	);

	pi.on("session_shutdown", () => {
		session = undefined;
		revision++;
		reporter.clear();

		for (const unsubscribe of subscriptions) unsubscribe();
	});
}
