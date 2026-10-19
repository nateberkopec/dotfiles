#!/usr/bin/env node

import { appendFileSync } from "node:fs";
import { join } from "node:path";

const args = process.argv.slice(2);
let result;
switch (args.slice(0, 2).join(" ")) {
	case "workspace list":
		result = { workspaces: [{ workspace_id: "w1", label: "Test" }] };
		break;
	case "agent list":
		result = {
			agents: [{ workspace_id: "w1", pane_id: "w1:p1", terminal_title_stripped: "\u03c0 \u00b7 Startup task" }],
		};
		break;
	case "pane report-metadata":
		appendFileSync(join(process.env.HERDR_PLUGIN_STATE_DIR, "metadata.jsonl"), `${JSON.stringify(args)}\n`);
		result = {};
		break;
	case "plugin list":
		result = { plugins: [] };
		break;
	default:
		throw new Error(`Unexpected Herdr command: ${args.join(" ")}`);
}
console.log(JSON.stringify({ result }));
