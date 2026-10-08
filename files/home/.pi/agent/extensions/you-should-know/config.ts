export const DEFAULT_THRESHOLD = 0.85;

export function globalThreshold(notify: (message: string) => void = () => {}): number {
	const raw = process.env.YSK_CONFIDENCE_THRESHOLD;

	if (raw === undefined) return DEFAULT_THRESHOLD;
	const value = Number(raw);

	if (raw.trim() && Number.isFinite(value) && value >= 0 && value <= 1) return value;
	notify("YSK_CONFIDENCE_THRESHOLD must be a number from 0 to 1; using 0.85.");

	return DEFAULT_THRESHOLD;
}
