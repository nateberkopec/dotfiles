// Vendored from https://github.com/forlorn-echo/pi-caffeinate at
// 3a7629bd3bb119cea6f428e1fca751c4f7089934 (MIT, Copyright (c) 2026 Abhishek Sinha).
// Kept behavior-identical on purpose: prefer upstream fixes over local patches.
// Vendored as a local file (instead of a Pi package) so Linux/Ubuntu convergence
// never executes the upstream macOS-only preinstall check.
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { spawn, spawnSync, type ChildProcess } from "node:child_process";

const CAFFEINATE_COMMAND = "caffeinate";
const ASSERTION_TIMEOUT_SECONDS = 300;
const REFRESH_INTERVAL_MS = 4 * 60 * 1_000;
const RETRY_INTERVAL_MS = 5_000;

/**
 * Keeps macOS awake while Pi is processing an agent run, including tool calls,
 * retries, compaction retries, queued continuations, and tools waiting for user
 * input. The assertion is released once the agent fully settles.
 *
 * Each caffeinate process has a five-minute timeout so a force-killed Pi process
 * cannot leave a permanent sleep assertion behind. While work remains active,
 * the assertion is replaced every four minutes.
 */
export default function piCaffeinate(pi: ExtensionAPI) {
	if (process.platform !== "darwin") return;

	const probe = spawnSync(CAFFEINATE_COMMAND, ["-h"], { stdio: "ignore" });
	if (probe.error) {
		pi.on("session_start", (_event, ctx) => {
			if (ctx.hasUI) {
				ctx.ui.notify(
					`pi-caffeinate is disabled: required command is not available on PATH: ${CAFFEINATE_COMMAND}`,
					"warning",
				);
			}
		});
		return;
	}

	let active = false;
	let assertion: ChildProcess | undefined;
	let pendingAssertion: ChildProcess | undefined;
	let refreshTimer: ReturnType<typeof setTimeout> | undefined;
	let retryTimer: ReturnType<typeof setTimeout> | undefined;
	let errorNotified = false;

	const clearTimers = () => {
		if (refreshTimer) clearTimeout(refreshTimer);
		if (retryTimer) clearTimeout(retryTimer);
		refreshTimer = undefined;
		retryTimer = undefined;
	};

	const scheduleRefresh = (ctx: ExtensionContext) => {
		if (refreshTimer) clearTimeout(refreshTimer);
		refreshTimer = setTimeout(() => {
			refreshTimer = undefined;
			launchAssertion(ctx);
		}, REFRESH_INTERVAL_MS);
		refreshTimer.unref?.();
	};

	const scheduleRetry = (ctx: ExtensionContext) => {
		if (!active || retryTimer) return;
		retryTimer = setTimeout(() => {
			retryTimer = undefined;
			launchAssertion(ctx);
		}, RETRY_INTERVAL_MS);
		retryTimer.unref?.();
	};

	const launchAssertion = (ctx: ExtensionContext) => {
		if (!active || pendingAssertion) return;

		const candidate = spawn(CAFFEINATE_COMMAND, ["-i", "-t", String(ASSERTION_TIMEOUT_SECONDS)], {
			stdio: "ignore",
		});
		pendingAssertion = candidate;

		candidate.once("spawn", () => {
			if (pendingAssertion === candidate) pendingAssertion = undefined;
			if (!active) {
				candidate.kill("SIGTERM");
				return;
			}

			const previous = assertion;
			assertion = candidate;
			previous?.kill("SIGTERM");
			errorNotified = false;
			scheduleRefresh(ctx);
		});

		candidate.once("error", (error) => {
			if (pendingAssertion === candidate) pendingAssertion = undefined;
			if (assertion === candidate) assertion = undefined;
			if (!errorNotified && ctx.hasUI) {
				errorNotified = true;
				ctx.ui.notify(`Unable to prevent macOS sleep: ${error.message}`, "warning");
			}
			scheduleRetry(ctx);
		});

		candidate.once("exit", () => {
			if (pendingAssertion === candidate) pendingAssertion = undefined;
			if (assertion !== candidate) return;
			assertion = undefined;
			if (refreshTimer) clearTimeout(refreshTimer);
			refreshTimer = undefined;
			scheduleRetry(ctx);
		});
	};

	const start = (ctx: ExtensionContext) => {
		active = true;
		if (!assertion && !pendingAssertion) launchAssertion(ctx);
	};

	const stop = () => {
		active = false;
		clearTimers();
		pendingAssertion?.kill("SIGTERM");
		assertion?.kill("SIGTERM");
		pendingAssertion = undefined;
		assertion = undefined;
	};

	pi.on("agent_start", (_event, ctx) => start(ctx));
	pi.on("agent_settled", () => stop());
	pi.on("session_shutdown", () => stop());
}
