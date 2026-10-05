import { execFileSync } from "node:child_process";
import { realpathSync } from "node:fs";
import { createRequire, registerHooks } from "node:module";
import { pathToFileURL } from "node:url";

// Use the installed Pi TUI rather than an imitation of wrapping and key parsing.
const requirePi = createRequire(realpathSync(execFileSync("which", ["pi"], { encoding: "utf8" }).trim()));
const url = pathToFileURL(requirePi.resolve("@earendil-works/pi-tui")).href;
registerHooks({ resolve: (specifier, context, next) => specifier === "@earendil-works/pi-tui"
	? { url, shortCircuit: true } : next(specifier, context) });
