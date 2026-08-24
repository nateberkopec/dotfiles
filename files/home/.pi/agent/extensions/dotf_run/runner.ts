import { spawn, spawnSync, type ChildProcess } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

export type RunResult = {
	exitCode: number | null;
	signal: NodeJS.Signals | null;
	error?: string;
	cleanupError?: string;
};

const TERMINAL_SIGNALS = ["SIGINT", "SIGQUIT", "SIGTERM"] as const;

function invalidateSudoTimestamp(): string | undefined {
	const result = spawnSync("/usr/bin/sudo", ["-k"], { stdio: "ignore" });
	if (result.error) return result.error.message;
	if (result.signal) return `sudo -k terminated by ${result.signal}`;
	if (result.status !== 0) return `sudo -k exited with code ${result.status}`;
	return undefined;
}

function runDotf(executable: string, repository: string, setChild: (child?: ChildProcess) => void): Promise<RunResult> {
	return new Promise((resolve) => {
		const child = spawn(executable, ["run"], { cwd: repository, stdio: "inherit" });
		setChild(child);

		let finished = false;
		const finish = (result: RunResult) => {
			if (finished) return;
			finished = true;
			setChild();
			resolve(result);
		};

		child.once("error", (error) => finish({ exitCode: null, signal: null, error: error.message }));
		child.once("exit", (exitCode, signal) => finish({ exitCode, signal }));
	});
}

function failure(result: RunResult): string | undefined {
	const failures: string[] = [];
	if (result.error) failures.push(`dotf run could not start: ${result.error}`);
	else if (result.signal) failures.push(`dotf run terminated by ${result.signal}`);
	else if (result.exitCode !== 0) failures.push(`dotf run exited with code ${result.exitCode}`);
	if (result.cleanupError) failures.push(result.cleanupError);
	return failures.length ? failures.join("; ") : undefined;
}

export async function executeDotf(ctx: ExtensionContext): Promise<RunResult> {
	if (ctx.mode !== "tui") throw new Error("dotf_run requires Pi's interactive TUI");

	const repository = join(homedir(), ".dotfiles");
	const executable = join(repository, "bin", "dotf");
	const result = await ctx.ui.custom<RunResult>((tui, _theme, _keybindings, done) => {
		let child: ChildProcess | undefined;
		const signalHandlers = TERMINAL_SIGNALS.map((signal) => {
			const handler = () => child?.kill(signal);
			process.on(signal, handler);
			return [signal, handler] as const;
		});

		tui.stop();
		void (async () => {
			let run: RunResult = { exitCode: null, signal: null };
			try {
				const error = invalidateSudoTimestamp();
				if (error) run.error = error;
				else run = await runDotf(executable, repository, (runningChild) => { child = runningChild; });
			} catch (error) {
				run.error = error instanceof Error ? error.message : String(error);
			} finally {
				try {
					const cleanupError = invalidateSudoTimestamp();
					if (cleanupError) run.cleanupError = cleanupError;
				} catch (error) {
					run.cleanupError = error instanceof Error ? error.message : String(error);
				} finally {
					for (const [signal, handler] of signalHandlers) process.off(signal, handler);
					tui.start();
					tui.requestRender(true);
				}
			}
			done(run);
		})();

		return { render: () => [], invalidate: () => {} };
	});

	if (!result) throw new Error("dotf_run was cancelled before execution completed");
	const error = failure(result);
	if (error) throw new Error(error);
	return result;
}
