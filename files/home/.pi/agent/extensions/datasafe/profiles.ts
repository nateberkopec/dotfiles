export interface Profile {
	providers: readonly string[] | "all";
	strategies: readonly string[];
	status?: string;
}

export const profiles: Readonly<Record<string, Profile>> = {
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
};

export const profile = profiles[process.env.PI_DATASAFE_MODE ?? ""] ?? profiles["usa-no-train"];
