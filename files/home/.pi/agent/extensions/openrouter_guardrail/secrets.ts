import { execFile } from "node:child_process";
import {
  OPENROUTER_API_KEY_REF,
  OPENROUTER_PROVISIONING_KEY_REF,
  SECRET_TIMEOUT_MS,
} from "./config";

export async function readOpenRouterApiKey(timeoutMs = SECRET_TIMEOUT_MS, ignoreEnv = false) {
  return readSecret(OPENROUTER_API_KEY_REF, timeoutMs, ignoreEnv);
}

export async function readOpenRouterProvisioningKey(timeoutMs = SECRET_TIMEOUT_MS, ignoreEnv = false) {
  return readSecret(OPENROUTER_PROVISIONING_KEY_REF, timeoutMs, ignoreEnv);
}

async function readSecret(ref: string, timeoutMs: number, ignoreEnv: boolean) {
  const envValue = ignoreEnv ? undefined : envFallback(ref);
  if (envValue) return envValue;

  return new Promise<string | undefined>((resolve) => {
    execFile(
      "op",
      ["--account", "thespeedshop", "read", ref],
      { timeout: timeoutMs, maxBuffer: 16 * 1024 },
      (error, stdout) => {
        if (error) {
          resolve(undefined);
          return;
        }

        const value = stdout.trim();
        resolve(value.length > 0 ? value : undefined);
      },
    );
  });
}

function envFallback(ref: string) {
  if (ref === OPENROUTER_API_KEY_REF) return process.env.OPENROUTER_API_KEY;
  if (ref === OPENROUTER_PROVISIONING_KEY_REF) {
    return process.env.OPENROUTER_PROVISIONING_KEY;
  }
}
