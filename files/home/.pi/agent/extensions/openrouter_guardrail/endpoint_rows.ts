import { OPENROUTER_BASE_URL, type PerformanceRow } from "./config";

export async function fetchEndpointRows(
  modelId: string,
  allowedProviders: string[],
  provisioningKey: string,
  minThroughputP50: number,
  maxLatencyP50: number,
): Promise<PerformanceRow[]> {
  const [author, ...slugParts] = modelId.split("/");
  const slug = slugParts.join("/");
  const response = await fetch(
    `${OPENROUTER_BASE_URL}/models/${encodeURIComponent(author)}/${encodeURIComponent(slug)}/endpoints`,
    { headers: { Authorization: `Bearer ${provisioningKey}` } },
  );

  if (!response.ok) return [];

  const payload = await response.json();
  return endpointObjects(payload)
    .map((endpoint: any) => toPerformanceRow(modelId, endpoint, minThroughputP50, maxLatencyP50))
    .filter((row) => allowedProviders.includes(row.provider));
}

function toPerformanceRow(
  modelId: string,
  endpoint: any,
  minThroughputP50: number,
  maxLatencyP50: number,
): PerformanceRow {
  const tag = String(endpoint.tag ?? "");
  const provider = tag.split("/")[0];
  const cacheable = endpoint.pricing?.input_cache_read != null && endpoint.pricing.input_cache_read !== "0";
  const latency = Number(endpoint.latency_last_30m?.p50 ?? Number.POSITIVE_INFINITY);
  const throughput = Number(endpoint.throughput_last_30m?.p50 ?? -1);

  return {
    model: modelId,
    provider,
    tag,
    quantization: String(endpoint.quantization ?? ""),
    cacheable,
    latency_p50_ms: latency,
    throughput_p50_tps: throughput,
    passes: cacheable && latency <= maxLatencyP50 && throughput >= minThroughputP50,
  };
}

function endpointObjects(payload: any) {
  const endpoints = payload?.data?.endpoints;
  if (!Array.isArray(endpoints)) return [];

  return endpoints
    .flatMap((endpoint) => (Array.isArray(endpoint) ? endpoint : [endpoint]))
    .filter((endpoint) => endpoint && typeof endpoint === "object");
}
