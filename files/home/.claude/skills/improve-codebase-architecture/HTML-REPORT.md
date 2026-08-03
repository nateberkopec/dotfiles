# HTML Report Format

Render the architecture review as one self-contained HTML file in the OS temp directory. Use Tailwind via CDN and highlight.js via CDN. Do not use Mermaid, SVG, or architecture diagrams: actual and proposed code carry the argument.

## Scaffold

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Architecture review — {{repo name}}</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/styles/github-dark.min.css" />
    <script src="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/highlight.min.js"></script>
    <script>
      document.addEventListener("DOMContentLoaded", () => typeof hljs === "undefined" || hljs.highlightAll());
    </script>
    <style>
      html, body { max-width: 100%; overflow-x: hidden; }
      main, section, article, figure { min-width: 0; max-width: 100%; }
      pre { box-sizing: border-box; tab-size: 2; width: 100%; }
      .code-scroll { color: #e2e8f0; max-width: 100%; scrollbar-width: thin; }
    </style>
  </head>
  <body class="bg-stone-50 text-slate-900 font-sans">
    <main class="max-w-6xl mx-auto px-6 py-12 space-y-12">
      <header>...</header>
      <section id="candidates" class="space-y-10">...</section>
      <section id="top-recommendation">...</section>
    </main>
  </body>
</html>
```

Tailwind and highlight.js are the only scripts. Keep the rest static. Guard the highlight call so a CDN failure does not raise an error, and keep the report readable when highlight.js is unavailable.

## Header

Show the repo name, date, and a compact legend:

- `Current code` — exact repository excerpt
- `Proposed sketch` — discussion code that may not compile
- `Test surface` — caller or test code showing the seam

If `CONTEXT.md` is absent, say so in one muted line. Follow the header with a compact **At a glance** section: state the top recommendation first, then give one short bullet per candidate. Do not add an introduction paragraph.

## Candidate card

Each candidate is one `<article>` with:

1. **Title** — name the ownership change, such as “Let Step execution own lifecycle state.”
2. **Badge row** — recommendation strength (`Strong` = emerald, `Worth exploring` = amber, `Speculative` = slate) and dependency category (`in-process`, `local-substitutable`, `ports & adapters`, `mock`).
3. **Files** — monospaced paths with `break-all` so long paths do not widen the mobile page.
4. **What happens today** — two or three sentences narrating the current call path and friction. Do not add a generic `Problem` heading.
5. **Current code** — an exact, representative repository excerpt with a file-path caption.
6. **Proposed direction** — two or three sentences naming the implementation ownership that moves behind the seam.
7. **Proposed code** — concrete code or pseudocode labeled `Proposed sketch`.
8. **Caller or test change** — optional second code pair showing how the interface or test surface shrinks.
9. **Why this is deeper** — one compact paragraph using interface, depth, seam, locality, leverage, and test surface where relevant.
10. **ADR callout** — only when the proposal conflicts with or materially resolves tension in an ADR.

Do not render separate `Problem`, `Solution`, `Benefits`, or `Deletion test` sections. The narrative and code should make those points concrete.

## Code presentation

### Side-by-side current and proposed code

Use this as the default centrepiece:

```html
<div class="grid lg:grid-cols-2 gap-5">
  <figure class="rounded-xl overflow-hidden border border-slate-300 bg-slate-950">
    <figcaption class="flex justify-between bg-slate-900 px-4 py-3 text-xs"><span class="font-semibold text-rose-300">Current code</span><code class="break-all text-slate-400">lib/orders/runner.rb</code></figcaption>
    <pre class="code-scroll overflow-x-auto p-4 text-sm leading-6"><code class="language-ruby">...</code></pre>
  </figure>
  <figure class="rounded-xl overflow-hidden border border-indigo-300 bg-slate-950">
    <figcaption class="flex justify-between bg-indigo-950 px-4 py-3 text-xs"><span class="font-semibold text-indigo-200">Proposed sketch</span><code class="break-all text-indigo-300">lib/orders/execution.rb</code></figcaption>
    <pre class="code-scroll overflow-x-auto p-4 text-sm leading-6"><code class="language-ruby">...</code></pre>
  </figure>
</div>
```

Escape HTML characters inside code. Keep excerpts short enough to compare without vertical hunting, usually 8–30 lines.

### Exactness rules

- Current excerpts must exist in the repository. Preserve names and meaningful control flow.
- Add a path caption to every current excerpt.
- Use `# ...` or the language’s normal omission marker when trimming unrelated code.
- Never silently rewrite current code to strengthen the argument.
- Proposed code may be pseudocode or incomplete, but must use plausible project names and language idioms.
- Start every non-current excerpt label with `Proposed`, such as `Proposed sketch`, `Proposed test surface`, or `Proposed caller change`; do not present it as a ready patch.
- Show dependencies and ownership explicitly instead of hiding them behind placeholders such as `do_the_thing`.
- Assign every block an explicit highlight.js class. Use `language-ruby` for `.rb`, `language-bash` for shell scripts and extensionless shell entry points, `language-yaml` for `.yml`/`.yaml`, `language-typescript` for `.ts`/`.tsx`, `language-javascript` for `.js`/`.jsx`, and `language-plaintext` when uncertain.
- Infer extensionless files from their shebang or contents; for example, `bin/dotf` is `language-bash`.
- Use the same language class for current and proposed versions of the same module.

### Caller or test changes

A candidate is easier to assess when the report shows leverage at a real call site. Prefer one small excerpt such as:

- a caller losing ordering or configuration knowledge
- a test replacing private-state surgery with the public interface
- several call sites collapsing into one module
- an adapter fake becoming smaller

Label current repository excerpts `Current test surface` or `Current caller`. Label discussion code `Proposed test surface` or `Proposed caller change`.

## Narrative guidance

Lead the reader through the code in this order:

1. “Today, this caller must know…”
2. Show the exact code.
3. “Move that ownership into…”
4. Show the proposed sketch.
5. “The caller/test then becomes…”
6. Explain why the resulting module is deeper.

Keep paragraphs short. Code should occupy more visual area than prose.

## Style guidance

- Lean editorial, not a corporate dashboard.
- Use generous whitespace and a serif heading if desired.
- Use dark code panels with restrained rose for current friction and indigo/emerald for proposed code.
- Use line wrapping only for prose; code scrolls horizontally.
- Keep highlight.js styling subordinate to the report: use one dark theme and do not add per-token custom colours.
- Preserve readable dark code panels before highlight.js loads or if its CDN is unavailable.
- On narrow screens, stack current and proposed code; on wide screens, show them side by side.
- Constrain the page and its main structural elements to the viewport, give code figures `min-width: 0`, make code blocks fill their figure, and allow file paths to break. The page must not scroll horizontally on a mobile viewport; only code blocks may scroll horizontally.

## Top recommendation

State the top recommendation in the **At a glance** section near the top. The final recommendation card may repeat only its name, one sentence explaining its leverage, and an anchor link. Do not repeat its code.

## Readability gate

Before opening the report, apply the `/readability` skill as required by `SKILL.md`. Audit extracted user-facing prose, not source code or HTML markup. Every deterministic audit check must report `PASS` at the default grade target; warnings also block presentation. Then inspect the rendered page for scanning, mobile stacking, code legibility, and working syntax highlighting.

## Tone and vocabulary

Plain English, concise, and concrete. Use the `/codebase-design` vocabulary consistently.

**Use exactly:** module, interface, implementation, depth, deep, shallow, seam, adapter, leverage, locality.

**Never substitute:** component, service, unit (for module) · API, signature (for interface) · boundary (for seam) · layer or wrapper (for module).

Good phrasing:

- “Today, Runner must know that checking completion also mutates errors.”
- “Move lifecycle state behind the Step execution seam.”
- “The proposed sketch gives tests the same interface callers use.”
- “Locality improves because privilege policy no longer depends on mixin order.”

Avoid generic claims such as “cleaner,” “more maintainable,” or “better separation.” Point to the code that creates locality or leverage.
