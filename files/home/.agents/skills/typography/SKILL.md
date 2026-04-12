---
name: typography
description: This skill should be used when selecting fonts, reviewing CSS typography, improving legibility, fixing link affordance, or reducing readability/accessibility risks in UI text.
---

# Typography

Apply this skill when UI text is hard to read, typography feels inconsistent, links are not clearly clickable, or contrast decisions are harming usability.

## Principles to apply

Ground decisions in NN/g guidance from:

- `references/nng-guidelines.md`
- https://www.nngroup.com/articles/glanceable-fonts/
- https://www.nngroup.com/videos/il1-typography-test/
- https://www.nngroup.com/articles/pairing-typefaces/
- https://www.nngroup.com/articles/serif-vs-sans-serif-fonts-hd-screens/
- https://www.nngroup.com/articles/guidelines-for-visualizing-links/
- https://www.nngroup.com/articles/low-contrast/

Core rules:

1. Optimize for legibility first (size, spacing, contrast).
2. Keep font systems simple and role-based (usually 1–2 families).
3. Preserve explicit link affordance.
4. Run IL1 checks for alphanumeric surfaces.
5. Avoid low-contrast text for primary UI and body copy.

## Workflow

1. Inventory current typography tokens/rules.
2. Define clear type roles:
   - Display/headline
   - Body
   - Meta/supporting text
3. Validate legibility basics:
   - Sufficient font size
   - Adequate line-height
   - Adequate contrast
4. Validate link presentation:
   - Clear clickability cues
   - Distinct visited state where relevant
5. Validate font choices for data-heavy/alphanumeric contexts with IL1 testing.
6. Run script checks and fix failures.

## Audit script

Run the bundled heuristic auditor:

```bash
ruby scripts/typography_audit.rb "app/assets/stylesheets/**/*.css"
```

You can scan mixed file types (CSS/SCSS/HTML with `<style>` blocks).

Generate an IL1 specimen page from discovered font families:

```bash
ruby scripts/typography_audit.rb "app/assets/stylesheets/**/*.css" --il1-html /tmp/il1.html
```

The script reports common risks:

- Small font sizes
- Tight line-height
- Low text/background contrast pairs
- Excessive family count
- Weak link affordance (e.g., removing underlines without replacement)
- Missing `:visited` color styles

Treat results as guardrails. Always apply visual review in real UI contexts.

## Output expectations

When using this skill in a user-facing task:

1. Provide specific typography changes (token/rule level).
2. Explain impact on legibility/comprehension.
3. Note any intentional tradeoffs (brand constraints, design-system compatibility, edge-case exceptions).
