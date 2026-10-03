// Resolve Pi's host-provided TUI package for standalone extension tests.
import { execFileSync } from "node:child_process";
import { createRequire, registerHooks } from "node:module";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const globalRoot = execFileSync("npm", ["root", "-g"], { encoding: "utf8" }).trim();
const requireFromPi = createRequire(join(globalRoot, "@earendil-works/pi-coding-agent", "package.json"));
const tuiUrl = pathToFileURL(requireFromPi.resolve("@earendil-works/pi-tui")).href;

registerHooks({
  resolve(specifier, context, nextResolve) {
    if (specifier === "@earendil-works/pi-tui") return { url: tuiUrl, shortCircuit: true };
    return nextResolve(specifier, context);
  },
});
