export interface Profile {
	providers: readonly string[] | "all";
	web: Readonly<Record<string, string>> | "all";
	strategies: readonly string[];
	status?: string;
}

const exaZdr = { web_search: "exa", web_contents: "exa" };

export const profiles: Readonly<Record<string, Profile>> = {
	"usa-no-train": {
		providers: ["openai", "meridian", "google-vertex", "fireworks", "openrouter", "vercel-ai-gateway"],
		web: exaZdr,
		strategies: ["openrouter", "fireworks", "vercel-ai-gateway"],
	},
	"claude-only": {
		providers: ["meridian", "anthropic"],
		web: exaZdr,
		strategies: [],
		status: "[PROFILE: CLAUDE-ONLY]",
	},
	unrestricted: {
		providers: "all",
		web: "all",
		strategies: [],
		status: "[WARNING: UNRESTRICTED]",
	},
};

export const profile = profiles[process.env.PI_DATASAFE_MODE ?? ""] ?? profiles["usa-no-train"];
