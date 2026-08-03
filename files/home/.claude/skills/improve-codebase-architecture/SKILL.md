---
name: improve-codebase-architecture
description: Scan a codebase for deepening opportunities, present them as a code-centered HTML report with current and proposed code, then grill through whichever one you pick.
license: "MIT; copyright Matt Pocock; see ../matt-pocock-skills-LICENSE.txt"
source: https://github.com/mattpocock/skills/tree/main/skills/engineering/improve-codebase-architecture
disable-model-invocation: true
---

# Improve Codebase Architecture

Surface architectural friction and propose **deepening opportunities** — refactors that turn shallow modules into deep ones. The aim is testability and AI-navigability.

This command is _informed_ by the project's domain model and built on a shared design vocabulary:

- Run the `/codebase-design` skill for the architecture vocabulary (**module**, **interface**, **depth**, **seam**, **adapter**, **leverage**, **locality**) and its principles (the deletion test, "the interface is the test surface", "one adapter = hypothetical seam, two = real"). Use these terms exactly in every suggestion — don't drift into "component," "service," "API," or "boundary."
- The domain language in `CONTEXT.md` gives names to good seams; ADRs in `docs/adr/` record decisions this command should not re-litigate.

## Process

### 1. Explore

Read the project's domain glossary (`CONTEXT.md`) and any ADRs in the area you're touching first.

Then use the Agent tool with `subagent_type=Explore` to walk the codebase. Don't follow rigid heuristics — explore organically and note where you experience friction:

- Where does understanding one concept require bouncing between many small modules?
- Where are modules **shallow** — interface nearly as complex as the implementation?
- Where have pure functions been extracted just for testability, but the real bugs hide in how they're called (no **locality**)?
- Where do tightly-coupled modules leak across their seams?
- Which parts of the codebase are untested, or hard to test through their current interface?

Apply the **deletion test** to anything you suspect is shallow: would deleting it concentrate complexity, or just move it? A "yes, concentrates" is the signal you want.

### 2. Present candidates as an HTML report

Write a self-contained HTML file to the OS temp directory so nothing lands in the repo. Resolve the temp dir from `$TMPDIR`, falling back to `/tmp` (or `%TEMP%` on Windows), and write to `<tmpdir>/architecture-review-<timestamp>.html` so each run gets a fresh file. Do not open or present it until the readability pass in step 3 succeeds.

The report uses **Tailwind via CDN** for layout and **highlight.js via CDN** for syntax highlighting. It is code-centered: explain each candidate by narrating a concrete refactor and showing real current code beside proposed code. Assign an explicit highlight.js language class to every code block instead of relying on automatic detection. Do not use Mermaid, SVG, architecture diagrams, or generic problem/solution/deletion-test sections.

For each candidate, render a card with:

- **Files** — which files/modules are involved
- **What happens today** — a short narrative grounded in an exact excerpt from the current code
- **Current code** — a small, representative excerpt copied from the repository and labeled with its file path; use ellipses only when omission is clear
- **Proposed direction** — a short narrative that names what ownership moves and why
- **Proposed code** — a concrete sketch using the project's language and names; pseudocode and non-compiling sketches are allowed, but label them `Proposed sketch`
- **Caller or test change** — when useful, show how a real caller or test becomes smaller or moves to the new interface
- **Why this is deeper** — a compact explanation in terms of interface, locality, leverage, seam, and test surface
- **Recommendation strength** — one of `Strong`, `Worth exploring`, `Speculative`, rendered as a badge

Prefer two or three focused code excerpts over a large synthetic rewrite. Proposed code must be specific enough to discuss method ownership, dependencies, and the test surface; avoid placeholder boxes or prose-only abstractions.

End the report with a **Top recommendation** section: which candidate you'd tackle first and why.

**Use CONTEXT.md vocabulary for the domain, and the `/codebase-design` vocabulary for the architecture.** If `CONTEXT.md` defines "Order," talk about "the Order intake module" — not "the FooBarHandler," and not "the Order service."

**ADR conflicts**: if a candidate contradicts an existing ADR, only surface it when the friction is real enough to warrant revisiting the ADR. Mark it clearly in the card (e.g. a warning callout: _"contradicts ADR-0007 — but worth reopening because…"_). Don't list every theoretical refactor an ADR forbids.

See [HTML-REPORT.md](HTML-REPORT.md) for the full HTML scaffold, code-presentation patterns, and styling guidance.

The proposed code is a discussion sketch, not an implementation plan. Do not edit the project.

### 3. Apply a readability pass

Run the `/readability` skill against the finished report before presenting it. The audience is a maintainer choosing which refactor to discuss; their task is to compare current and proposed code quickly.

- Front-load a compact **At a glance** section with the top recommendation and one short bullet per candidate.
- Keep headings descriptive, paragraphs short, and labels consistent. Preserve exact current-code excerpts during prose edits.
- Extract the report's user-facing prose to `<tmpdir>/architecture-review-<timestamp>-prose.md`. Exclude code samples, scripts, styles, HTML attributes, file paths, and badge labels; preserve headings and lists.
- Run the readability skill's bundled `readability_audit.rb` against that prose file with its default grade target of 10.
- Fix every warning and failed check in both the HTML report and extracted prose, then rerun the audit until every check reports `PASS`. Required architecture and domain terms may remain, but simplify the surrounding sentences rather than skipping a check.
- Check the rendered HTML for scanning, mobile stacking, code legibility, and working syntax highlighting. Do not treat a passing script as sufficient by itself.

After the pass succeeds, open the HTML file for the user — `xdg-open <path>` on Linux, `open <path>` on macOS, `start <path>` on Windows — tell them the absolute path, briefly summarize the readability changes, and ask: "Which of these would you like to explore?"

### 4. Grilling loop

Once the user picks a candidate, run the `/grilling` skill to walk the design tree with them — constraints, dependencies, the shape of the deepened module, what sits behind the seam, what tests survive.

Side effects happen inline as decisions crystallize — run the `/domain-modeling` skill to keep the domain model current as you go:

- **Naming a deepened module after a concept not in `CONTEXT.md`?** Add the term to `CONTEXT.md`. Create the file lazily if it doesn't exist.
- **Sharpening a fuzzy term during the conversation?** Update `CONTEXT.md` right there.
- **User rejects the candidate with a load-bearing reason?** Offer an ADR, framed as: _"Want me to record this as an ADR so future architecture reviews don't re-suggest it?"_ Only offer when the reason would actually be needed by a future explorer to avoid re-suggesting the same thing — skip ephemeral reasons ("not worth it right now") and self-evident ones.
- **Want to explore alternative interfaces for the deepened module?** Run the `/codebase-design` skill and use its design-it-twice parallel sub-agent pattern.
