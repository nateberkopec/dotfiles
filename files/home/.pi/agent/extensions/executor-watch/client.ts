// Polls through Pi's configured MCP gateway; this extension handles no credentials.
export type Watch = { app: string; run: string };
export type RunHandle = { id: string; app: string; workflow: string; status: string; output?: unknown; error?: unknown };
export type TrackingError = { id: string; status: "tracking_error"; error: string };
type ToolResult = { content?: { type: string; text?: string }[]; details?: unknown };
type RuntimeCall = { version: 1; server: string; tool: string; args: unknown; result?: Promise<{ ok: true; result: ToolResult } | { ok: false; error: Error }> };
export type Emit = (channel: string, request: RuntimeCall) => void;

export function executorValue(result: ToolResult): unknown {
  const text = (result.content ?? []).filter(item => item.type === "text" && item.text).map(item => item.text).join("\n");
  const candidates: unknown[] = [];
  for (const item of result.content ?? []) {
    if (item.type !== "text" || !item.text) continue;
    try { candidates.push(JSON.parse(item.text.split("\nstructuredContent:\n")[0])); } catch { /* Gateway may append human-readable text. */ }
  }
  // pi-mcp-adapter preserves the upstream MCP result in details.
  candidates.push((result.details as { mcpResult?: { structuredContent?: unknown } } | undefined)?.mcpResult?.structuredContent);
  for (const candidate of candidates) {
    const value = candidate as { status?: string; execution?: { ok: boolean; value?: unknown; error?: unknown } } | undefined;
    if (value?.status !== "completed" || !value.execution) continue;
    if (!value.execution.ok) throw new Error(`Executor operation failed: ${JSON.stringify(value.execution.error)}`);
    return value.execution.value;
  }
  throw new Error(`Executor did not return a completed execution: ${text || "no response text"}`);
}

export async function workflowGet(emit: Emit, { app, run }: Watch): Promise<RunHandle> {
  // Pin the server so a selected-client default can't reroute the call.
  const request: RuntimeCall = { version: 1, server: "server-1", tool: "server-1_execute", args: { code: `const profiles = Object.keys(tools.executor.profiles);
if (profiles.length !== 1) throw new Error("Expected one Executor profile, found " + profiles.length);
return await tools.executor.profiles[profiles[0]].queries.workflows_get(${JSON.stringify({ path: { app, run } })});` } };
  emit("pi-mcp-adapter:runtime-tool-call:v1", request);
  if (!request.result) throw new Error("pi-mcp-adapter is not loaded");
  const outcome = await request.result;
  if (!outcome.ok) throw outcome.error;
  const handle = executorValue(outcome.result) as RunHandle;
  if (!handle || handle.id !== run || handle.app !== app || typeof handle.workflow !== "string" ||
    !["queued", "running", "waiting", "paused", "waitingForPause", "complete", "errored", "terminated"].includes(handle.status)) {
    throw new Error("Invalid Executor workflow run");
  }
  return handle;
}
export const terminal = (run: RunHandle) => ["complete", "errored", "terminated"].includes(run.status);

export async function observe(
  watch: Watch,
  get: (watch: Watch) => Promise<RunHandle>,
  signal: AbortSignal,
  deliver: (value: RunHandle | TrackingError) => void,
  sleep: (signal: AbortSignal) => Promise<void>,
) {
  let errors = 0;
  while (!signal.aborted) {
    try {
      const value = await get(watch);
      if (signal.aborted) return;
      errors = 0;
      if (terminal(value)) { deliver(value); return; }
    } catch (error) {
      if (signal.aborted) return;
      // Don't lose a run on one network failure; don't silently poll forever either.
      if (++errors >= 5) { deliver({ id: watch.run, status: "tracking_error", error: String(error) }); return; }
    }
    try { await sleep(signal); } catch { return; }
  }
}
