import {
  CACHE_VERSION,
  PERFORMANCE_CACHE_TTL_MS,
  performanceCachePath,
  type ModelCache,
  type PerformanceCache,
  type PerformanceRow,
} from "./config";
import { fetchEndpointRows } from "./endpoint_rows";
import { readJson, writeJson } from "./json_cache";

export async function getPerformanceRows(
  modelCache: ModelCache,
  provisioningKey: string,
  forceRefresh: boolean,
) {
  const minThroughputP50 = Number(process.env.OPENROUTER_MIN_THROUGHPUT_P50 ?? 50);
  const maxLatencyP50 = Number(process.env.OPENROUTER_MAX_LATENCY_P50 ?? 2000);
  const cached = await readJson<PerformanceCache>(performanceCachePath);

  if (isFresh(cached, modelCache, minThroughputP50, maxLatencyP50, forceRefresh)) {
    return cached.rows;
  }

  const rows = (
    await mapLimit(modelCache.allowedModels, 6, (modelId) =>
      fetchEndpointRows(modelId, modelCache.allowedProviders, provisioningKey, minThroughputP50, maxLatencyP50),
    )
  ).flat();

  await writeJson(performanceCachePath, {
    version: CACHE_VERSION,
    fetchedAt: Date.now(),
    guardrailName: modelCache.guardrailName,
    minThroughputP50,
    maxLatencyP50,
    rows,
  });

  return rows;
}

function isFresh(
  cached: PerformanceCache | undefined,
  modelCache: ModelCache,
  minThroughputP50: number,
  maxLatencyP50: number,
  forceRefresh: boolean,
): cached is PerformanceCache {
  return Boolean(
    !forceRefresh &&
      cached &&
      cached.version === CACHE_VERSION &&
      cached.guardrailName === modelCache.guardrailName &&
      cached.minThroughputP50 === minThroughputP50 &&
      cached.maxLatencyP50 === maxLatencyP50 &&
      Date.now() - cached.fetchedAt < PERFORMANCE_CACHE_TTL_MS,
  );
}

async function mapLimit<T>(items: T[], limit: number, fn: (item: T) => Promise<PerformanceRow[]>) {
  const results: PerformanceRow[][] = [];
  let nextIndex = 0;

  async function worker() {
    while (nextIndex < items.length) {
      const currentIndex = nextIndex;
      nextIndex += 1;
      results[currentIndex] = await fn(items[currentIndex]);
    }
  }

  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return results;
}
