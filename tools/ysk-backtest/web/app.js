const $ = (id) => document.getElementById(id);

const token = new URL(location.href).searchParams.get("token");

const categories = {
	wrong_result: "Wrong result",
	cost: "Monetary cost",
	wasted_work: "Wasted work",
	data_loss: "Data loss",
	security: "Security",
	verification: "Verification (historical)",
	none: "None",
};

let data,
	index = 0,
	selected,
	busy = false;

const percent = (value) => (Number.isFinite(value) ? `${Math.round(value * 100)}%` : "Not recorded");

async function api(route, body) {
	const response = await fetch(`/api/${route}`, {
		method: body === undefined ? "GET" : "POST",
		headers: { "X-Review-Token": token, "Content-Type": "application/json" },
		body: body === undefined ? undefined : JSON.stringify(body),
	});

	const result = await response.json();

	if (!response.ok) throw Error(result.error || `Request failed (${response.status}).`);

	return result;
}

function error(message = "") {
	$("error").textContent = message;
	$("error").hidden = !message;
}

function renderWarning() {
	const warnings = data.warnings;
	index = Math.max(0, Math.min(index, warnings.length - 1));
	const item = warnings[index];
	$("position").textContent = `${item ? index + 1 : 0} / ${warnings.length}`;
	$("previous").disabled = !item || index === 0;
	$("next").disabled = !item || index >= warnings.length - 1;
	const signature = warnings.map((warning) => warning.id).join(",");

	if ($("timeline").dataset.signature !== signature) {
		$("timeline").dataset.signature = signature;
		$("timeline").replaceChildren(
			...warnings.map((warning, position) => {
				const button = document.createElement("button");
				button.textContent = position + 1;
				button.setAttribute("aria-label", `Warning ${position + 1}`);
				button.setAttribute("aria-current", String(position === index));
				button.onclick = () => {
					index = position;
					renderWarning();
				};

				return button;
			}),
		);
	}

	for (const [position, button] of [...$("timeline").children].entries())
		button.setAttribute("aria-current", String(position === index));

	if (selected === item?.id && item) return;
	selected = item?.id;
	$("context").scrollTop = 0;
	$("warning-title").textContent = item
		? "Heads up"
		: data.mode === "recorded"
			? "No recorded warnings"
			: "No warnings yet";
	$("warning").textContent = item?.note || "";
	$("guidance").hidden = Boolean(item);
	$("guidance").textContent =
		data.mode === "recorded"
			? "Run the current policy to generate warnings from this session."
			: data.status === "done"
				? "The replay finished without a warning. Nothing to review."
				: "Warnings will appear here as the replay progresses.";
	$("meta").textContent = item
		? `${categories[item.decision?.category] || item.decision?.category || "Category not recorded"} • ${item.timestamp || "Time not recorded"}`
		: "";
	$("checkpoint").textContent = item ? `Entry ${item.id}` : "";
	$("context-detail").textContent = !item
		? "Select a warning to inspect its historical snapshot."
		: item.exactSnapshot
			? "Exact transcript snapshot used by the observer; no future turns included."
			: "Reconstructed context at the recorded note. The original snapshot was not saved, so async timing may differ.";
	$("context").textContent = item?.source || "";
	$("decision").replaceChildren();

	if (item)
		for (const [label, value] of [
			["Jev confidence", percent(item.decision?.confidence)],
			["P(warn)", percent(item.decision?.probability)],
			["Mode", data.mode === "recorded" ? "Historical warning" : "Current-policy replay"],
			[
				data.mode === "replay" || item.decision?.thresholdMetric === "confidence"
					? "Confidence threshold"
					: "P(warn) threshold",
				data.mode === "replay" ? percent(data.threshold) : percent(item.decision?.threshold),
			],
		]) {
			const group = document.createElement("div"),
				term = document.createElement("dt"),
				definition = document.createElement("dd");

			term.textContent = label;
			definition.textContent = value;
			group.append(term, definition);
			$("decision").append(group);
		}
}

async function refresh() {
	data = await api("state");
	const running = ["starting", "running"].includes(data.status);
	$("session-name").textContent = data.session.name;
	$("session-detail").textContent =
		`${data.session.entries} branch entries • ${data.total} eligible checkpoints • ${data.session.cwd || "Working directory not recorded"}`;
	$("run").disabled = running || !data.total;
	$("stop").hidden = !running;
	$("recorded").disabled = running || data.mode === "recorded";
	$("file").disabled = running;
	$("confidence").disabled = running;
	$("usage").textContent = data.mode === "replay" ? data.usage || "" : "No inference calls";
	$("status").textContent =
		data.mode === "recorded"
			? `${data.warnings.length} recorded warnings`
			: `${{ starting: "Starting", running: "Replaying", done: "Finished", stopped: "Stopped", error: "Failed" }[data.status] || "Ready"}: ${data.completed} / ${data.total} checkpoints; ${data.warnings.length} warnings`;
	error(data.error);
	renderWarning();
}

async function act(action) {
	if (busy) return;
	busy = true;

	try {
		await action();
		await refresh();
	} catch (err) {
		error(err.message);
	} finally {
		busy = false;
	}
}

$("run").onclick = () =>
	act(async () => {
		if (!$("confidence").value || !$("confidence").reportValidity()) return;

		if (
			!confirm(
				`Replay ${data.total} checkpoints? Historical text will be sent to Jev/Luna. Provider charges apply. Results stay in memory.`,
			)
		)
			return;
		index = 0;
		selected = undefined;
		await api("replay", { threshold: Number($("confidence").value) / 100 });
	});

$("stop").onclick = () => act(() => api("stop", {}));

$("recorded").onclick = () =>
	act(async () => {
		index = 0;
		selected = undefined;
		await api("recorded", {});
	});

$("file").onchange = () =>
	act(async () => {
		const file = $("file").files[0];

		if (!file) return;

		if (file.size > 64 * 1024 * 1024) throw Error("Session exceeds the 64 MiB limit.");
		await api("session", { name: file.name, text: await file.text() });
		index = 0;
		selected = undefined;
		$("file").value = "";
	});

$("previous").onclick = () => {
	index--;
	renderWarning();
};

$("next").onclick = () => {
	index++;
	renderWarning();
};

document.addEventListener("keydown", (event) => {
	if (["INPUT", "TEXTAREA", "PRE"].includes(event.target.tagName) || event.ctrlKey || event.metaKey || event.altKey)
		return;

	if (event.key === "ArrowLeft" && !$("previous").disabled) {
		event.preventDefault();
		$("previous").click();
	}

	if (event.key === "ArrowRight" && !$("next").disabled) {
		event.preventDefault();
		$("next").click();
	}
});

async function poll() {
	if (!busy)
		try {
			await refresh();
		} catch (err) {
			error(`${err.message} Is the utility still running?`);
		}

	setTimeout(poll, 1000);
}

poll();
