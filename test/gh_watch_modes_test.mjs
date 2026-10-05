import assert from "node:assert/strict";
import { test } from "node:test";
import { remote, observe } from "../files/home/.pi/agent/extensions/gh-watch/client.ts";
const result = (workflow, status = "running", output) => ({ structuredContent: { status: "completed", execution: { ok: true,
  value: { id: "watch-pr", workflow, status, ...(output ? { output } : {}) } } } });

test("remote defaults to PR checks and only explicitly selects one Actions run", async () => {
  for (const mode of [undefined, "pr", "run"]) {
    const name = mode === "run" ? "watch_actions_run" : "watch_pr_checks";
    const value = await remote(async args => {
      assert.ok(args.args.code.includes(`mutations.${name}`));
      return result(name);
    }, "start", {}, new AbortController().signal, mode);
    assert.equal(value.workflow, name);
  }
  await assert.rejects(remote(async () => result("watch_actions_run"), "start", {}, new AbortController().signal), /Invalid/);
});
test("one PR observer delivers only the consolidated terminal result", async () => {
  const output = { outcome: "completed", conclusion: "failure", counts: { pass: 2, fail: 1, pending: 0, skipping: 0, cancel: 0 } };
  let polls = 0, deliveries = [];
  await observe("watch-pr", async () => ++polls === 1 ? result("watch_pr_checks", "waiting") : result("watch_pr_checks", "complete", output),
    new AbortController().signal, value => deliveries.push(value), async () => {});
  assert.equal(deliveries.length, 1);
  assert.deepEqual(deliveries[0].output, output);
});
