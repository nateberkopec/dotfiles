import { randomUUID } from "node:crypto";
import type { ProviderHeaders, SimpleStreamOptions, TranscriptContext } from "@earendil-works/pi-ai";

export function header(headers: ProviderHeaders, name: string): string | undefined {
	return Object.entries(headers).find(([key]) => key.toLowerCase() === name)?.[1] ?? undefined;
}
export function setHeader(headers: ProviderHeaders, name: string, value: string): void {
	for (const key of Object.keys(headers)) if (key.toLowerCase() === name) delete headers[key];
	headers[name] = value;
}
function deleteHeader(headers: ProviderHeaders, name: string): void {
	for (const key of Object.keys(headers)) if (key.toLowerCase() === name) delete headers[key];
}
export function auxiliaryHeaders(headers: ProviderHeaders | undefined, kind: string, sessionId: string): ProviderHeaders {
	const result = { ...headers };
	if (header(result, "x-meridian-agent") !== "pi") return result;
	for (const name of ["x-session-affinity", "x-opencode-session", "x-session-id", "x-parent-session-id"]) {
		deleteHeader(result, name);
	}
	setHeader(result, "x-session-affinity", sessionId);
	setHeader(result, "x-meridian-source", `subagent-${kind}`);
	// Meridian currently has no provider-neutral aliases for these two fields.
	setHeader(result, "x-opencode-agent-mode", "subagent");
	setHeader(result, "x-opencode-agent-name", kind);
	return result;
}

export type RequestState = { sessionId?: string; compacting?: boolean; child?: boolean };
export function requestOptions(context: TranscriptContext, options: SimpleStreamOptions | undefined, state: RequestState): SimpleStreamOptions {
	const headers = { ...options?.headers };
	setHeader(headers, "x-meridian-agent", "pi");
	const sessionId = options?.sessionId ?? header(headers, "x-session-affinity") ?? randomUUID();
	const childName = context.messages.flatMap((message) => {
		if (message.role !== "system") return [];
		return typeof message.content === "string" ? [message.content] : message.content.map((block) => block.text);
	})
		.map((text) => text.match(/^<active_agent name="([^"]{1,64})"\/>/)?.[1]
			?.replace(/[^\x20-\x7e]/g, (character) => `\\u${character.charCodeAt(0).toString(16).padStart(4, "0")}`)).find(Boolean);
	const auxiliary = state.compacting || (!childName && !state.child && state.sessionId && sessionId !== state.sessionId);
	let result: ProviderHeaders;
	if (auxiliary) {
		result = auxiliaryHeaders(headers, state.compacting ? "compaction" : "generate", sessionId);
	} else {
		result = headers;
		// The request's own session ID also isolates foreground children that bypass extension hooks.
		if (!header(result, "x-session-affinity") ||
			(state.sessionId && sessionId !== state.sessionId && header(result, "x-session-affinity") === state.sessionId)) {
			setHeader(result, "x-session-affinity", sessionId);
		}
		setHeader(result, "x-opencode-agent-mode", childName || state.child ? "subagent" : "primary");
		setHeader(result, "x-opencode-agent-name", childName ?? (state.child ? "subagent" : "pi"));
	}
	if (!header(result, "x-request-id")) setHeader(result, "x-request-id", randomUUID());
	return { ...options, headers: result };
}
