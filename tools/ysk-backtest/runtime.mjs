import { readFile } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { profile } from "../../files/home/.pi/agent/extensions/datasafe/profiles.ts";

export async function observerContext() {
	if (profile.providers !== "all" && !profile.providers.includes("openai")) throw Error("YSK is unavailable in this Datasafe profile.");
	if (!process.env.TYPESAFE_API_KEY) throw Error("TYPESAFE_API_KEY is missing; launch from a new Fish terminal.");
	let sdk;
	try { sdk = await import("@earendil-works/pi-coding-agent"); }
	catch {
		let root;
		try { root = execFileSync("mise", ["where", "npm:@earendil-works/pi-coding-agent"], { encoding: "utf8" }).trim(); }
		catch { throw Error("Pi SDK was not found. Install Pi with mise or make its package resolvable by Node."); }
		const packageRoot = path.join(root, "node_modules/@earendil-works/pi-coding-agent");
		const manifest = JSON.parse(await readFile(path.join(packageRoot, "package.json"), "utf8"));
		sdk = await import(pathToFileURL(path.join(packageRoot, manifest.exports?.["."]?.import || manifest.main)).href);
	}
	const { ModelRuntime, ModelRegistry } = sdk;
	const modelRegistry = new ModelRegistry(await ModelRuntime.create());
	const model = modelRegistry.find("openai", "gpt-6-luna");
	if (!model || !modelRegistry.hasConfiguredAuth(model)) throw Error("openai/gpt-6-luna or its credentials are unavailable.");
	return { modelRegistry };
}
