import { spawn, spawnSync, type ChildProcess, type StdioOptions } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

export type RunResult = {
	exitCode: number | null;
	signal: NodeJS.Signals | null;
	error?: string;
	cleanupError?: string;
	output?: string;
};

const TERMINAL_SIGNALS = ["SIGINT", "SIGQUIT", "SIGTERM"] as const;

const OUTPUT_TAIL_LINES = 40;

function invalidateSudoTimestamp(): string | undefined {
	const result = spawnSync("/usr/bin/sudo", ["-k"], { stdio: "ignore" });

	if (result.error) return result.error.message;

	if (result.signal) return `sudo -k terminated by ${result.signal}`;

	if (result.status !== 0) return `sudo -k exited with code ${result.status}`;

	return undefined;
}

function runDotf(
	executable: string,
	repository: string,
	interactive: boolean,
	setChild: (child?: ChildProcess) => void,
	capture = false,
): Promise<RunResult> {
	const env = { ...process.env };

	if (interactive) delete env.NONINTERACTIVE;
	else env.NONINTERACTIVE = "1";

	return new Promise((resolve) => {
		const stdio: StdioOptions = capture ? ["ignore", "pipe", "pipe"] : "inherit";
		const child = spawn(executable, ["run"], { cwd: repository, stdio, env });
		setChild(child);

		let output = "";
		const append = (chunk: Buffer) => {
			output += chunk.toString();
		};
		child.stdout?.on("data", append);
		child.stderr?.on("data", append);

		let finished = false;

		const finish = (result: RunResult) => {
			if (finished) return;
			finished = true;
			setChild();
			resolve(capture ? { ...result, output: output.trimEnd().split("\n").slice(-OUTPUT_TAIL_LINES).join("\n") } : result);
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

function checked(result: RunResult): RunResult {
	const error = failure(result);

	if (error) throw new Error(result.output ? `${error}\n\n${result.output}` : error);

	return result;
}

export async function executeDotf(ctx: ExtensionContext, interactive = true): Promise<RunResult> {
	const repository = join(homedir(), ".dotfiles");
	const executable = join(repository, "bin", "dotf");

	if (ctx.mode !== "tui") {
		if (interactive) throw new Error("Interactive dotf_run requires Pi's interactive TUI; use interactive=false");

		return checked(await runDotf(executable, repository, false, () => {}, true));
	}

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
				const error = interactive ? invalidateSudoTimestamp() : undefined;

				if (error) run.error = error;
				else
					run = await runDotf(executable, repository, interactive, (runningChild) => {
						child = runningChild;
					});
			} catch (error) {
				run.error = error instanceof Error ? error.message : String(error);
			} finally {
				try {
					const cleanupError = interactive ? invalidateSudoTimestamp() : undefined;

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

	return checked(result);
}
