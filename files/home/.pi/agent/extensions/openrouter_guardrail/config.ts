export const OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1";
export const DEFAULT_GUARDRAIL_NAME = "US Cached Models Only";
export const CACHE_VERSION = 1;
export const MODEL_CACHE_TTL_MS = 6 * 60 * 60 * 1000;
export const PERFORMANCE_CACHE_TTL_MS = 10 * 60 * 1000;
export const QUICK_AUTH_TIMEOUT_MS = 1_500;
export const SECRET_TIMEOUT_MS = 10_000;

export const OPENROUTER_API_KEY_REF = "op://Employee/Nate Openrouter Key/password";
export const OPENROUTER_PROVISIONING_KEY_REF = "op://Employee/OpenRouter Provisioning Key/password";
const cacheDir = `${process.env.HOME}/.pi/agent/cache`;
export const modelCachePath = `${cacheDir}/openrouter-guardrail-models.json`;
export const performanceCachePath = `${cacheDir}/openrouter-guardrail-performance.json`;

export type PiModel = {
  id: string;
  name: string;
  reasoning: boolean;
  input: ("text" | "image")[];
  contextWindow: number;
  maxTokens: number;
  cost: { input: number; output: number; cacheRead: number; cacheWrite: number };
  compat: Record<string, unknown>;
};

export type ModelCache = {
  version: number;
  fetchedAt: number;
  guardrailName: string;
  allowedModels: string[];
  allowedProviders: string[];
  models: PiModel[];
};

export type PerformanceRow = {
  model: string;
  provider: string;
  tag: string;
  quantization: string;
  cacheable: boolean;
  latency_p50_ms: number;
  throughput_p50_tps: number;
  passes: boolean;
};

export type PerformanceCache = {
  version: number;
  fetchedAt: number;
  guardrailName: string;
  minThroughputP50: number;
  maxLatencyP50: number;
  rows: PerformanceRow[];
};

export type ModelCacheState = {
  getLatest(): ModelCache | undefined;
  setLatest(cache: ModelCache): void;
};
