import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { reviewTranscript } from "./review.ts";
import { transcript } from "./transcript.ts";
import { UsageLedger, type UsageRecord } from "./usage.ts";
import { KEY, ObserverUI } from "./ui.ts";
import { WarningInbox, REVIEW_SHORTCUT, type Warning } from "./inbox.ts";
import { registerChat } from "./chat.ts";
import { TopicHistory } from "./history.ts";
import { globalThreshold } from "./config.ts";

export default function youShouldKnow(pi: ExtensionAPI) {
	let enabled = true, threshold = globalThreshold(), lastSource = "", lastStarted = 0, warned = "", runCancelled = false;
	let thresholdOverride: number | undefined;
	let epoch = 0, ledger = new UsageLedger(), ui: ObserverUI | undefined;
	let controller: AbortController | undefined, pending: Promise<void> | undefined;
	let inbox = new WarningInbox(), history = new TopicHistory();
	const cancel = () => { controller?.abort(); controller = undefined; pending = undefined; ui?.stop(); ui?.closeCard(); };
	const view = (ctx: ExtensionContext) => ui ??= new ObserverUI(ctx, ledger);
	const display = (ctx: ExtensionContext) => {
		const version = epoch, warning = enabled ? inbox.current : undefined, count = inbox.pending.length;
		return view(ctx).note(warning?.note ?? "", () => epoch === version && warning === (enabled ? inbox.current : undefined)
			&& count === inbox.pending.length, false, warning?.decision, count);
	};
	const acknowledge = async (ctx: ExtensionContext, warning = inbox.current) => {
		if (!warning || !inbox.pending.some((item) => item.id === warning.id)) return;
		inbox.acknowledge(warning.id); pi.appendEntry(`${KEY}-acknowledged`, { id: warning.id });
		chat.close(); await display(ctx);
	};
	const chat = registerChat(pi, () => enabled && inbox.current ? inbox.current : { id: "", note: "", source: "" }, acknowledge, (ctx) => {
		const version = epoch;
		return (record) => { if (version === epoch) { ledger.add(record); pi.appendEntry(`${KEY}-usage`, record); view(ctx).footer(); } };
	});
	const restore = async (_event: unknown, ctx: ExtensionContext) => {
		cancel(); chat.restore(ctx); epoch++; enabled = true; thresholdOverride = undefined;
		threshold = globalThreshold((message) => ctx.ui.notify(message, "warning")); history = new TopicHistory();
		inbox = WarningInbox.restore(ctx.sessionManager.getBranch());
		lastSource = ""; lastStarted = 0; warned = ""; runCancelled = false; ledger = new UsageLedger();
		for (const entry of ctx.sessionManager.getBranch()) {
			if (entry.type !== "custom") continue;
			const data = entry.data as any;
			if (entry.customType === `${KEY}-state`) {
				if (typeof data?.enabled === "boolean") enabled = data.enabled;
				if (data?.threshold === null) { thresholdOverride = undefined; threshold = globalThreshold(); }
				else if (Number.isFinite(data?.threshold) && data.threshold >= 0 && data.threshold <= 1) threshold = thresholdOverride = data.threshold;
			}
			if (entry.customType === `${KEY}-understood`) history.understand(data?.note);
			if (entry.customType === `${KEY}-note` && typeof data?.note === "string") {
				history.offer(data.previous); // Recover the last offered topic from older cleared-note entries.
				history.offer(data.note);
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
				const operation = reviewTranscript(ctx, source, history, threshold, request.signal, usage, waiting,
					() => inbox.current ? Promise.resolve() : screen.note("Reviewing a possible issue", () => controller === request && !request.signal.aborted, true));
				const result = await Promise.race([operation, interrupted]);
				if (!result || request.signal.aborted || controller !== request) return;
				const { choice, probability, confidence, category, model } = result.decision;
				pi.appendEntry(`${KEY}-review`, { choice, probability, confidence, category, model, threshold, thresholdMetric: "confidence" });
				if (result.note && !history.has(result.note)) {
					history.offer(result.note);
					const warning: Warning = { note: result.note, id: crypto.randomUUID(), source, decision: { confidence, category } };
					inbox.add(warning); pi.appendEntry(`${KEY}-note`, { ...warning, queued: true });
				}
				await display(ctx);
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
	pi.registerCommand("ysk-understood", {
		description: "Mark the selected Heads-up understood, suppress that topic, and acknowledge it.",
		handler: async (_args, ctx) => {
			const warning = enabled ? inbox.current : undefined;
			if (!warning) { ctx.ui.notify("No current YSK warning to mark understood.", "warning"); return; }
			history.understand(warning.note); pi.appendEntry(`${KEY}-understood`, { id: warning.id, note: warning.note });
			await acknowledge(ctx, warning);
		},
	});
	pi.registerCommand("ysk-demo", {
		description: "YSK observer: on, off, default (global confidence), or a session confidence threshold from 0 to 1",
		handler: async (args, ctx) => {
			const action = args.trim(), value = Number(action);
			if (action === "on" || action === "off") { cancel(); enabled = action === "on"; }
			else if (action === "default") {
				cancel(); thresholdOverride = undefined; threshold = globalThreshold((message) => ctx.ui.notify(message, "warning"));
			}
			else if (action && Number.isFinite(value) && value >= 0 && value <= 1) { cancel(); threshold = thresholdOverride = value; }
			else { ctx.ui.notify("Usage: /ysk-demo on|off|default|<0–1>", "warning"); return; }
			lastSource = ""; lastStarted = 0; warned = "";
			if (!enabled) chat.close();
			pi.appendEntry(`${KEY}-state`, { enabled, threshold: thresholdOverride ?? null }); view(ctx).footer(); await display(ctx);
		},
	});
	const reviewWarnings = async (ctx: ExtensionContext) => {
		if (!enabled || !inbox.current) return;
		const version = epoch;
		const result = await view(ctx).review(ctx, inbox, (warning) => { void acknowledge(ctx, warning); });
		if (version !== epoch || !enabled) return;
		await display(ctx);
		if (result && inbox.pending.some((warning) => warning.id === result.details.id)) await chat.open(ctx, result.details);
	};
	pi.registerShortcut(REVIEW_SHORTCUT, { description: "Review persistent YSK warnings", handler: reviewWarnings });
	pi.registerCommand("ysk-inbox", { description: "Review pending YSK warnings (Ctrl+;)", handler: async (_args, ctx) => reviewWarnings(ctx) });
	pi.on("session_start", restore);
	pi.on("session_tree", restore);
	pi.on("agent_start", () => { runCancelled = false; });
	pi.on("message_end", (event, ctx) => { if (event.message.role === "assistant") void review(ctx, false, event.message); });
	pi.on("agent_end", async (_event, ctx) => { const version = epoch; await pending; if (version === epoch) await review(ctx, true); });
	pi.on("session_shutdown", () => { cancel(); chat.close(); });
}
