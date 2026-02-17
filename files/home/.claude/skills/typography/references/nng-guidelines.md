# NN/g typography source notes

This file captures the specific takeaways used by the `typography` skill.

## Sources

1. [Typography for Glanceable Reading: Bigger Is Better](https://www.nngroup.com/articles/glanceable-fonts/)
2. [The IL1 Typography Test (Video)](https://www.nngroup.com/videos/il1-typography-test/)
3. [The Dos and Don'ts of Pairing Typefaces](https://www.nngroup.com/articles/pairing-typefaces/)
4. [Serif vs. Sans-Serif Fonts for HD Screens](https://www.nngroup.com/articles/serif-vs-sans-serif-fonts-hd-screens/)
5. [Guidelines for Visualizing Links](https://www.nngroup.com/articles/guidelines-for-visualizing-links/)
6. [Low-Contrast Text Is Not the Answer](https://www.nngroup.com/articles/low-contrast/)

## Extracted principles

### 1) Glanceability for short UI text

For quick, glanceable text (notifications, labels, status chips):

- Prefer larger sizes.
- Avoid condensed widths.
- Avoid thin/light styles at small sizes.
- Avoid all-lowercase when text must be read instantly.

### 2) Distinguish similar glyphs (IL1 test)

- Check candidate fonts for differentiation among:
  - uppercase `I`
  - lowercase `l`
  - numeral `1`
- This matters most in alphanumeric UI: codes, IDs, account numbers, tables.

### 3) Pair typefaces with role clarity

- Keep families limited (usually 1–2).
- Use decorative type sparingly (typically display-level only).
- Assign explicit roles (headers vs body vs metadata).
- Prefer strong hierarchy with size/weight/style, not random family mixing.

### 4) Serif vs sans-serif on modern screens

- On HD screens, strict "sans only" rules are outdated.
- Serif vs sans differences are often small; choose based on context, readability, and brand tone.
- Continue to avoid overly stylized fonts for body copy.

### 5) Links need strong affordance

- Color + underline is the strongest default signal for clickability.
- If underlines are removed, add clear replacement cues and maintain accessibility.
- Style visited links distinctly from unvisited links.
- Do not underline non-link text.

### 6) Avoid low-contrast text

- Low contrast harms legibility, findability, confidence, and accessibility.
- Avoid using contrast reduction as a decluttering tactic.
- Prefer alternatives: reduce density, reposition elements, use hierarchy, progressive disclosure.
