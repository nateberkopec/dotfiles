import { isToolCallEventType, type ExtensionAPI } from "@mariozechner/pi-coding-agent";

const FIND_COMMAND_PATTERN = /(?:^|&&|\|\||[;|\n(])\s*(?:command\s+)?(?:sudo\s+)?find(?:\s|$)/;
const MAX_FIND_TIMEOUT_SECONDS = 2;

function hasFindCommand(command: string): boolean {
	return FIND_COMMAND_PATTERN.test(command);
}

function validFindTimeout(timeout: number | undefined): boolean {
	return typeof timeout === "number" && timeout > 0 && timeout <= MAX_FIND_TIMEOUT_SECONDS;
}

export default function findTimeoutExtension(pi: ExtensionAPI) {
	pi.on("tool_call", async (event) => {
		if (!isToolCallEventType("bash", event)) return undefined;
		if (!hasFindCommand(event.input.command)) return undefined;
		if (validFindTimeout(event.input.timeout)) return undefined;

		return {
			block: true,
			reason:
				`find commands must set timeout <= ${MAX_FIND_TIMEOUT_SECONDS}s. ` +
				`Retry this bash call with {"timeout": ${MAX_FIND_TIMEOUT_SECONDS}}.`,
		};
	});
}
