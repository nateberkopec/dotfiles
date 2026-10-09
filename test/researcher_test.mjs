import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const definition = readFileSync(
	process.env.RESEARCHER_DEFINITION ?? new URL("../files/home/.agents/researcher.md", import.meta.url),
	"utf8",
);

const [, frontmatter, prompt] = definition.split(/^---\s*$/m);

const field = (name) => frontmatter.match(new RegExp(`^${name}: (.+)$`, "m"))?.[1];

test("researcher uses only available builtins and server-1 Executor tools", () => {
	assert.deepEqual(field("tools").split(/,\s*/), [
		"read",
		"write",
		"mcp:server-1/skills",
		"mcp:server-1/execute",
		"mcp:server-1/resume",
	]);
	assert.doesNotMatch(definition, /mcpScript/);
});

test("researcher defaults to background execution for ambient MCP registration", () => {
	assert.equal(field("async"), "true");
});

test("researcher discovers Exa within Executor and stops rather than substituting providers", () => {
	assert.match(prompt, /Use only server-1's Exa app through Executor/);
	assert.match(prompt, /app: "executor", name: "executor"/);
	assert.match(prompt, /tools\.search\(\{query: "exa"\}\)/);
	assert.match(prompt, /tools\.search\.describe/);
	assert.match(prompt, /Do not guess tool paths, profile IDs, account IDs, or arguments/);
	assert.match(
		prompt,
		/report the exact blocker to the supervisor rather than switching providers or answering from memory/,
	);
	assert.match(prompt, /do not rerun their source/);
});
