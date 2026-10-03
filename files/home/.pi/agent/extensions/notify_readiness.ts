// Adapted from https://github.com/nateberkopec/pi-ding/blob/af4d8fbe67f2aff9cebcee31f30a6b0eb69ba8c4/extensions/readiness.ts (MIT).
export type ReadyContext = {
	isIdle(): boolean;
	hasPendingMessages(): boolean;
};

type Schedule = {
	id?: unknown;
	paused?: unknown;
	activeRunId?: unknown;
	trigger?: unknown;
};

type Rpc = (method: "status" | "manage", params?: Record<string, unknown>) => Promise<unknown>;

function record(value: unknown): Record<string, unknown> {
	return value !== null && typeof value === "object" ? value as Record<string, unknown> : {};
}

function activeDescendants(reply: unknown): number {
	const envelope = record(reply);
	if (envelope.success !== true) throw new Error("pi-ding: pi-subagents status request failed");
	const fleet = record(record(envelope.data).fleet);
	const count = fleet.totalActive;
	if (fleet.version !== 1 || typeof count !== "number" || !Number.isSafeInteger(count) || count < 0) {
		throw new Error("pi-ding: pi-subagents returned no valid fleet status");
	}
	return count;
}

function schedules(reply: unknown): Schedule[] {
	const envelope = record(reply);
	if (envelope.success !== true) throw new Error("pi-ding: pi-subagents schedule request failed");
	const records = record(record(record(envelope.data).details).schedules).records;
	if (!Array.isArray(records)) throw new Error("pi-ding: pi-subagents returned no valid schedule list");
	return records.map((value) => record(value));
}

function pending(schedule: Schedule): boolean {
	if (schedule.paused === true) return false;
	const trigger = record(schedule.trigger);
	return typeof schedule.activeRunId === "string" || typeof trigger.nextRunAt === "string";
}

/** Coordinates one notification for each transition from session work to human-ready. */
export class ReadyNotificationGate {
	private armed = false;
	private notified = true;
	private revision = 0;
	private evaluating = false;
	private reevaluate = false;
	private readonly scheduleIds = new Set<string>();
	private readonly rpc: Rpc;
	private readonly notify: () => void;

	constructor(rpc: Rpc, notify: () => void) {
		this.rpc = rpc;
		this.notify = notify;
	}

	reset(scheduleIds: Iterable<string> = []): void {
		this.revision++;
		this.armed = false;
		this.notified = true;
		this.scheduleIds.clear();
		for (const id of scheduleIds) this.scheduleIds.add(id);
	}

	markBusy(): void {
		this.revision++;
		this.armed = true;
		this.notified = false;
	}

	trackSchedule(id: string): void {
		this.scheduleIds.add(id);
	}

	untrackSchedule(id: string): void {
		this.scheduleIds.delete(id);
	}

	async settle(ctx: ReadyContext): Promise<void> {
		if (!this.armed || this.notified || !ctx.isIdle() || ctx.hasPendingMessages()) return;
		if (this.evaluating) {
			this.reevaluate = true;
			return;
		}
		this.evaluating = true;
		const revision = this.revision;
		try {
			if (await this.blocked()) return;
			if (revision !== this.revision || !ctx.isIdle() || ctx.hasPendingMessages()) return;
			this.notify();
			this.notified = true;
		} finally {
			this.evaluating = false;
			if (this.reevaluate) {
				this.reevaluate = false;
				await this.settle(ctx);
			}
		}
	}

	private async blocked(): Promise<boolean> {
		if (activeDescendants(await this.rpc("status")) > 0) return true;
		if (this.scheduleIds.size === 0) return false;
		const current = schedules(await this.rpc("manage", { action: "schedule.list" }));
		const found = new Set<string>();
		for (const schedule of current) {
			if (typeof schedule.id !== "string" || !this.scheduleIds.has(schedule.id)) continue;
			found.add(schedule.id);
			if (pending(schedule)) return true;
		}
		for (const id of this.scheduleIds) {
			if (!found.has(id)) this.scheduleIds.delete(id);
		}
		return false;
	}
}
