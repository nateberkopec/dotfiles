---
name: readability
description: This skill should be used when writing or revising web content, product copy, AI-generated responses, docs, or long-form text where clarity, scannability, and comprehension matter.
---

# Readability

Apply this skill to turn dense copy into web-friendly content that people can scan, understand, and use quickly.

## Principles to apply

Ground decisions in NN/g guidance from:

- `references/nng-guidelines.md`
- https://www.nngroup.com/articles/genai-write-for-the-web/
- https://www.nngroup.com/articles/formatting-long-form-content/
- https://www.nngroup.com/articles/legibility-readability-comprehension/

Core rules:

1. Keep copy concise.
2. Structure for scanning, not essay-style reading.
3. Use the inverted pyramid (answer first, details second).
4. Use plain language and short sentences.
5. Design for comprehension, not just grammatical correctness.

## Workflow

1. Define audience and task.
2. Cut nonessential content before reformatting.
3. Rewrite lead sections to front-load key information.
4. Add scan aids:
   - Descriptive headings
   - Bullets for parallel points
   - Brief summary or key takeaways for long content
   - Selective emphasis only where it materially aids scanning
5. Confirm language simplicity and sentence-level clarity.
6. Run the readability audit script and address failures.

## Audit script

Use the bundled script for deterministic checks:

```bash
ruby scripts/readability_audit.rb <file>
```

Optional comparison to baseline branch:

```bash
ruby scripts/readability_audit.rb <file> --branch main
```

Optional grade target (default is 10):

```bash
ruby scripts/readability_audit.rb <file> --target-grade 9
```

The script reports:

- Flesch-Kincaid grade
- Sentence and paragraph length pressure
- Heading/list density for longer content
- Lead-paragraph length

Treat the script as a guardrail, not a substitute for human judgment.

## Output expectations

When using this skill in a user-facing task:

1. Deliver the revised text.
2. Briefly summarize structural changes (for example: "added summary, split long paragraphs, converted dense section to bullets").
3. Call out unresolved tradeoffs (brand voice, legal constraints, required jargon).
