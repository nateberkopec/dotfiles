import { execFileSync } from "node:child_process";
import { existsSync, realpathSync } from "node:fs";
import { registerHooks } from "node:module";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

// Resolve from the real SDK package, not a package-manager-generated CLI wrapper.
const globalRoot = execFileSync("npm", ["root", "-g"], { encoding: "utf8" }).trim();

let agent = join(globalRoot, "@earendil-works", "pi-coding-agent", "package.json");

if (!existsSync(agent)) {
	const install = execFileSync("mise", ["where", "npm:@earendil-works/pi-coding-agent"], { encoding: "utf8" }).trim();
	agent = join(install, "node_modules", "@earendil-works", "pi-coding-agent", "package.json");
}

const parentURL = pathToFileURL(realpathSync(agent)).href;

const packages = new Set(["@earendil-works/pi-tui", "@earendil-works/pi-ai", "@earendil-works/pi-ai/compat", "@earendil-works/pi-coding-agent", "typebox"]);

registerHooks({
	resolve: (specifier, context, next) =>
		next(specifier, packages.has(specifier) ? { ...context, parentURL } : context),
});
