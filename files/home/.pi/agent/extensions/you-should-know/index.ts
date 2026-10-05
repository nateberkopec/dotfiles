import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { reviewTranscript } from "./review.ts";
import { transcript } from "./transcript.ts";
import { UsageLedger, type UsageRecord } from "./usage.ts";
import { KEY, ObserverUI } from "./ui.ts";
import { registerChat } from "./chat.ts";

export default function youShouldKnow(pi: ExtensionAPI) {
	let enabled = true, threshold = 0.85, note = "", previous = "", lastSource = "", lastStarted = 0, warned = "", runCancelled = false;
	let epoch = 0, ledger = new UsageLedger(), ui: ObserverUI | undefined;
	let controller: AbortController | undefined, pending: Promise<void> | undefined;
	let issueId = "", issueSource = "";
	const cancel = () => { controller?.abort(); controller = undefined; pending = undefined; ui?.stop(); };
	const view = (ctx: ExtensionContext) => ui ??= new ObserverUI(ctx, ledger);
	const display = (ctx: ExtensionContext) => {
		const version = epoch, text = enabled ? note : "";
		return view(ctx).note(text, () => epoch === version && text === (enabled ? note : ""));
	};
	const chat = registerChat(pi, () => ({ id: issueId, note: enabled ? note : "", source: issueSource }), async (ctx) => {
		note = ""; issueId = ""; issueSource = ""; pi.appendEntry(`${KEY}-note`, { note, previous }); await display(ctx);
	}, (ctx) => {
		const version = epoch;
		return (record) => { if (version === epoch) { ledger.add(record); pi.appendEntry(`${KEY}-usage`, record); view(ctx).footer(); } };
	});
	const restore = async (_event: unknown, ctx: ExtensionContext) => {
		cancel(); chat.restore(ctx); epoch++; enabled = true; threshold = 0.85; note = ""; previous = ""; issueId = ""; issueSource = "";
		lastSource = ""; lastStarted = 0; warned = ""; runCancelled = false; ledger = new UsageLedger();
		for (const entry of ctx.sessionManager.getBranch()) {
			if (entry.type !== "custom") continue;
			const data = entry.data as any;
			if (entry.customType === `${KEY}-state`) {
				if (typeof data?.enabled === "boolean") enabled = data.enabled;
				if (Number.isFinite(data?.threshold) && data.threshold >= 0 && data.threshold <= 1) threshold = data.threshold;
			}
			if (entry.customType === `${KEY}-note` && typeof data?.note === "string") {
				note = data.note.replace(/[\u0000-\u001f\u007f-\u009f]/g, " ").slice(0, 600);
				previous = typeof data.previous === "string" ? data.previous.slice(0, 600) : note;
				issueId = typeof data.id === "string" ? data.id : "";
				issueSource = typeof data.source === "string" ? data.source.slice(-24_000) : "";
			}
		}
		// Match native footer accounting: all session branches represent money already spent.
		for (const entry of ctx.sessionManager.getEntries()) {
			if (entry.type === "custom" && entry.customType === `${KEY}-usage`) ledger.add(entry.data as UsageRecord);
		}
		ui = new ObserverUI(ctx, ledger); ui.footer(); await display(ctx);
	};
	const review = (ctx: ExtensionContext, final = false, assistant?: { content?: unknown }): Promise<void> | undefined => {
		if (!enabled || runCancelled || ctx.signal?.aborted) return;
		if (pending || (!final && Date.now() - lastStarted < 30_000)) return pending;
		const source = transcript(ctx, assistant);
		if (!source || source === lastSource) return;
		lastSource = source; lastStarted = Date.now();
		const request = new AbortController(), version = epoch, screen = view(ctx);
		controller = request;
		const waiting = (active: boolean) => { if (controller === request) screen.waiting(active); };
		const usage = (record: UsageRecord) => {
			if (version !== epoch) return;
			ledger.add(record); pi.appendEntry(`${KEY}-usage`, record); screen.footer();
		};
		const interrupted = new Promise<undefined>((resolve) => request.signal.addEventListener("abort", () => resolve(undefined), { once: true }));
		const runSignal = ctx.signal;
		const abortRun = () => { if (version === epoch) runCancelled = true; request.abort(); };
		runSignal?.addEventListener("abort", abortRun, { once: true });
		const timer = setTimeout(() => request.abort(), 40_000);
		pending = (async () => {
			try {
				const operation = reviewTranscript(ctx, source, previous, threshold, request.signal, usage, waiting,
					() => screen.note("Reviewing a possible issue", () => controller === request && !request.signal.aborted, true));
				const result = await Promise.race([operation, interrupted]);
				if (!result || request.signal.aborted || controller !== request) return;
				const { probability, confidence, category, model } = result.decision;
				pi.appendEntry(`${KEY}-review`, { probability, confidence, category, model, threshold });
				note = result.note === previous ? "" : result.note;
				if (note) previous = note;
				issueId = note ? crypto.randomUUID() : ""; issueSource = note ? source : "";
				pi.appendEntry(`${KEY}-note`, { note, previous, id: issueId, source: issueSource }); await display(ctx);
			} catch (error) {
				if (request.signal.aborted || controller !== request) return;
				const message = error instanceof Error && /^(TYPESAFE_API_KEY|YSK is|Jev HTTP|Jev returned|openai\/gpt-6-luna|Luna failed)/.test(error.message)
					? error.message : "YSK request failed; no fallback or retry was attempted.";
				if (message !== warned) { warned = message; ctx.ui.notify(message, "warning"); }
			} finally {
				clearTimeout(timer); runSignal?.removeEventListener("abort", abortRun);
				if (controller === request) { waiting(false); controller = undefined; pending = undefined; await display(ctx); }
			}
		})();
		return pending;
	};
	pi.registerCommand("ysk-demo", {
		description: "YSK observer: on, off, or a threshold from 0 to 1 (default on)",
		handler: async (args, ctx) => {
			const action = args.trim(), value = Number(action);
			if (action === "on" || action === "off") { cancel(); enabled = action === "on"; }
			else if (action && Number.isFinite(value) && value >= 0 && value <= 1) { cancel(); threshold = value; }
			else { ctx.ui.notify("Usage: /ysk-demo on|off|<0–1>", "warning"); return; }
			lastSource = ""; lastStarted = 0; warned = "";
			if (!enabled) { note = ""; issueId = ""; issueSource = ""; chat.close(); }
			pi.appendEntry(`${KEY}-state`, { enabled, threshold });
			pi.appendEntry(`${KEY}-note`, { note, previous, id: issueId, source: issueSource }); view(ctx).footer(); await display(ctx);
		},
	});
	pi.on("session_start", restore);
	pi.on("session_tree", restore);
	pi.on("agent_start", () => { runCancelled = false; });
	pi.on("message_end", (event, ctx) => { if (event.message.role === "assistant") void review(ctx, false, event.message); });
	pi.on("agent_end", async (_event, ctx) => { const version = epoch; await pending; if (version === epoch) await review(ctx, true); });
	pi.on("session_shutdown", () => { cancel(); chat.close(); });
}
