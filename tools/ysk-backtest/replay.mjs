import { TopicHistory } from "../../files/home/.pi/agent/extensions/you-should-know/history.ts";
import { reviewTranscript } from "../../files/home/.pi/agent/extensions/you-should-know/review.ts";
import { UsageLedger } from "../../files/home/.pi/agent/extensions/you-should-know/usage.ts";

export async function replay(points, threshold, state, signal, review = reviewTranscript, ctx) {
	const history = new TopicHistory(),
		ledger = new UsageLedger();

	state.status = "running";
	state.completed = 0;
	state.warnings = [];
	state.error = "";

	try {
		for (const point of points) {
			signal.throwIfAborted();
			state.current = point.id;
			const request = new AbortController();
			const abort = () => request.abort();
			signal.addEventListener("abort", abort, { once: true });
			const timer = setTimeout(abort, 40_000);

			try {
				const interrupted = new Promise((_, reject) =>
					request.signal.addEventListener(
						"abort",
						() => reject(Error(signal.aborted ? "Replay stopped." : "Observer timed out after 40 seconds.")),
						{ once: true },
					),
				);

				const result = await Promise.race([
					review(
						ctx,
						point.source,
						history,
						threshold,
						request.signal,
						(record) => {
							ledger.add(record);
							state.usage = ledger.footer();
						},
						() => {},
					),
					interrupted,
				]);

				signal.throwIfAborted();

				if (result.note && !history.has(result.note)) {
					history.offer(result.note);
					state.warnings.push({ ...point, note: result.note, decision: result.decision, exactSnapshot: true });
				}

				state.completed++;
			} finally {
				clearTimeout(timer);
				signal.removeEventListener("abort", abort);
			}
		}

		state.status = "done";
	} catch (error) {
		state.status = signal.aborted ? "stopped" : "error";
		state.error = signal.aborted ? "" : error.message;
	}
}
