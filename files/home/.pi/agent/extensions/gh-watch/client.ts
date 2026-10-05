// All remote calls use Pi's configured MCP gateway; this extension handles no credentials.
export const profile = "ins_e2cd8dae-9c1d-4c99-a570-3220f7ee63ca";
export type WatchHandle = { id: string; workflow: string; status: string; output?: unknown; error?: string };
export type GatewayResult = { isError?: boolean; content?: { type: string; text?: string }[]; structuredContent?: unknown; details?: unknown };
export type CallGateway = (args: unknown, signal: AbortSignal) => Promise<GatewayResult>;

export function executorValue(result: GatewayResult): unknown {
  if (result.isError) throw new Error("MCP call failed; inspect the nested MCP error.");
  const candidates = [result.structuredContent];
  for (const item of result.content ?? []) {
    if (item.type !== "text" || !item.text) continue;
    try { candidates.push(JSON.parse(item.text.split("\nstructuredContent:\n")[0])); } catch { /* Gateway may append human-readable text. */ }
  }
  // pi-mcp-adapter preserves the upstream MCP result in details.
  const details = result.details as { mcpResult?: { structuredContent?: unknown } } | undefined;
  candidates.push(details?.mcpResult?.structuredContent);
  for (const candidate of candidates) {
    const value = candidate as { status?: string; execution?: { ok: boolean; value?: unknown; error?: unknown } } | undefined;
    if (value?.status !== "completed" || !value.execution) continue;
    if (!value.execution.ok) throw new Error(`Executor operation failed: ${JSON.stringify(value.execution.error)}`);
    return value.execution.value;
  }
  throw new Error("Executor did not return a completed execution. No automatic retry: check approvals/input or inspect the start key before retrying.");
}

export async function remote(call: CallGateway, action: "start" | "status" | "cancel", input: unknown, signal: AbortSignal, mode: "pr" | "run" = "pr"): Promise<WatchHandle> {
  const name = action === "start" ? (mode === "pr" ? "watch_pr_checks" : "watch_actions_run") : action === "status" ? "watch_get" : "watch_cancel";
  const catalog = action === "status" ? "queries" : "mutations";
  // Search on each execution to fail clearly on profile/deployment drift, rather than silently using a different credential.
  const path = `tools["gh-agent"].profiles[${JSON.stringify(profile)}].${catalog}.${name}`;
  const code = `const found = await tools.search({ query: ${JSON.stringify(name)} });
if (!found.items.some(item => item.path === ${JSON.stringify(path)})) throw new Error("Expected gh-agent watch tool/profile unavailable; rediscover gh-agent.");
return await ${path}(${JSON.stringify(input)});`;
  const handle = executorValue(await call({ tool: "server-1_execute", args: { code } }, signal)) as WatchHandle;
  if (!handle || typeof handle.id !== "string" || !["watch_pr_checks", "watch_actions_run"].includes(handle.workflow) ||
    (action === "start" && handle.workflow !== name) ||
    !["queued", "running", "waiting", "paused", "waitingForPause", "complete", "errored", "terminated"].includes(handle.status)) {
    throw new Error("Invalid gh-agent watch handle");
  }
  return handle;
}
export const terminal = (run: WatchHandle) => ["complete", "errored", "terminated"].includes(run.status);

export async function observe(
  run: string,
  call: CallGateway,
  signal: AbortSignal,
  deliver: (value: WatchHandle | { id: string; status: "tracking_error" }) => void,
  sleep: (signal: AbortSignal) => Promise<void>,
) {
  let errors = 0;
  while (!signal.aborted) {
    try {
      const value = await remote(call, "status", { run }, signal);
      if (signal.aborted) return;
      errors = 0;
      if (terminal(value)) { deliver(value); return; }
    } catch {
      if (signal.aborted) return;
      // Don't lose a job on one network failure; don't silently poll forever either.
      if (++errors >= 5) { deliver({ id: run, status: "tracking_error" }); return; }
    }
    try { await sleep(signal); } catch { return; }
  }
}
