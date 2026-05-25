export const STATUS_KEY = "toksec";
export const CUSTOM_TYPE = "toksec";
export const MIN_GENERATION_MS = 50;

export type ModelRef = {
	provider: string;
	id: string;
};

export type ActiveMeasurement = {
	model: ModelRef;
	requestStartedAt: number;
	firstOutputAt?: number;
	deltaChars: number;
};

export type AggregateStats = {
	count: number;
	outputTokens: number;
	generationMs: number;
	ttftMs: number;
};

export type ToksecEntry = {
	version: 1;
	kind: "sample";
	provider: string;
	modelId: string;
	outputTokens: number;
	generationMs: number;
	ttftMs: number;
	timestamp: string;
};
