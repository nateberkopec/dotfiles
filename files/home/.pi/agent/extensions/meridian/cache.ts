import { mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { dirname, join } from "node:path";
import { getAgentDir } from "@earendil-works/pi-coding-agent";
import type { Api, Model } from "@earendil-works/pi-ai";
import { BASE_URL, buildModels } from "./catalog";

export const CACHE_TTL_MS = 7 * 24 * 60 * 60 * 1000;
export function catalogCachePath(): string {
	return join(getAgentDir(), "cache", "meridian-models.json");
}

export function readCatalogCache(anthropicModels: readonly Model<Api>[], path = catalogCachePath(), now = Date.now()) {
	try {
		const cached = JSON.parse(readFileSync(path, "utf8"));
		if (cached.version !== 1 || cached.baseUrl !== BASE_URL || !Number.isSafeInteger(cached.fetchedAt) || cached.fetchedAt <= 0 ||
			cached.fetchedAt > now || now - cached.fetchedAt > CACHE_TTL_MS) return [];
		return buildModels(cached.catalog, anthropicModels);
	} catch {
		return [];
	}
}

// Store only a validated model catalog, never prompts, tools, credentials, or request headers.
export function writeCatalogCache(catalog: unknown, path = catalogCachePath(), now = Date.now()): void {
	const temporary = `${path}.${randomUUID()}.tmp`;
	try {
		buildModels(catalog, []);
		mkdirSync(dirname(path), { recursive: true });
		writeFileSync(temporary, JSON.stringify({ version: 1, baseUrl: BASE_URL, fetchedAt: now, catalog }), { mode: 0o600 });
		renameSync(temporary, path);
	} catch {
		// Discovery must still work with a read-only or unavailable cache directory.
	} finally {
		try { rmSync(temporary, { force: true }); } catch { /* Best-effort cache cleanup. */ }
	}
}
