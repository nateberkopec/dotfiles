export interface Profile {
	providers: readonly string[] | "all";
	strategies: readonly string[];
	status?: string;
}

export const profiles = {
	"usa-no-train": {
		providers: ["openai", "meridian", "google-vertex", "fireworks", "openrouter", "vercel-ai-gateway"],
		strategies: ["openrouter", "fireworks", "vercel-ai-gateway"],
	},
	"claude-only": {
		providers: ["meridian", "anthropic"],
		strategies: [],
		status: "[PROFILE: CLAUDE-ONLY]",
	},
	unrestricted: {
		providers: "all",
		strategies: [],
		status: "[WARNING: UNRESTRICTED]",
	},
} satisfies Record<string, Profile>;

export const profile: Profile =
	Object.entries(profiles).find(([name]) => name === process.env.PI_DATASAFE_MODE)?.[1] ?? profiles["usa-no-train"];
