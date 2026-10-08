import { Type } from "typebox";
import { Value } from "typebox/value";

const LIMIT = 50;

const clean = (text: string) =>
	text
		.replace(/\p{Cc}/gu, " ")
		.trim()
		.slice(0, 600);

const key = (text: string) =>
	clean(text)
		.toLowerCase()
		.replace(/\s+/g, " ")
		.replace(/[.!]+$/, "");

export class TopicHistory {
	readonly offered: string[] = [];
	readonly understood: string[] = [];
	private add(list: string[], value: string | undefined) {
		if (!Value.Check(Type.String(), value) || !key(value)) return;
		const index = list.findIndex((text) => key(text) === key(value));

		if (index >= 0) list.splice(index, 1);
		list.push(clean(value));

		if (list.length > LIMIT) list.shift();
	}
	offer(value: string | undefined) {
		this.add(this.offered, value);
	}
	understand(value: string | undefined) {
		this.add(this.understood, value);
	}
	has(text: string) {
		return [...this.offered, ...this.understood].some((prior) => key(prior) === key(text));
	}
	state(source: string) {
		return (
			`Previously offered topics (skip repeats and paraphrases):\n${JSON.stringify(this.offered)}\n\n` +
			`Topics the user explicitly understood (never offer again):\n${JSON.stringify(this.understood)}\n\nTranscript:\n${source}`
		);
	}
}
