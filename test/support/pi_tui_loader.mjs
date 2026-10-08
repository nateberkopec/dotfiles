import { execFileSync } from "node:child_process";
import { existsSync, realpathSync } from "node:fs";
import { createRequire, registerHooks } from "node:module";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

// Resolve from the real SDK package, not a package-manager-generated CLI wrapper.
const globalRoot = execFileSync("npm", ["root", "-g"], { encoding: "utf8" }).trim();

let agent = join(globalRoot, "@earendil-works", "pi-coding-agent", "package.json");

if (!existsSync(agent)) {
	const install = execFileSync("mise", ["where", "npm:@earendil-works/pi-coding-agent"], { encoding: "utf8" }).trim();
	agent = join(install, "node_modules", "@earendil-works", "pi-coding-agent", "package.json");
}

const requirePi = createRequire(realpathSync(agent));

const url = pathToFileURL(requirePi.resolve("@earendil-works/pi-tui")).href;

registerHooks({
	resolve: (specifier, context, next) =>
		specifier === "@earendil-works/pi-tui" ? { url, shortCircuit: true } : next(specifier, context),
});
