---
name: github-readme
description: This skill should be used when creating or revising a GitHub README for a software project, including section structure, onboarding flow, examples, and contribution guidance.
---

# GitHub README

Use this skill to produce a README that helps visitors decide quickly whether to use the project and how to get started.

## Goal

A good GitHub README should answer, in order:

1. What is this project?
2. Why should I use it?
3. How do I run it right now?
4. How do I configure common cases?
5. How do I contribute?

## Workflow

1. Identify audience and primary use case.
2. Write a short value-first opening section.
3. Add a runnable quickstart with copy-pastable commands.
4. Add usage examples for the 1–3 most common tasks.
5. Add configuration/reference sections only after core onboarding is complete.
6. Add contributor guidance or link to `CONTRIBUTING.md`.
7. Run the README audit script and fix failures.
8. If prose still feels dense, apply the `readability` skill afterward.

## Suggested section order

Use this order by default (adapt as needed):

- Project name
- Short value proposition
- Features / capabilities
- Installation
- Quickstart / usage
- Configuration (if applicable)
- Development / testing
- Contributing
- License

## Style constraints

- Prefer concrete examples over abstract claims.
- Keep setup commands in fenced code blocks.
- Keep each section focused on one user question.
- Avoid burying setup steps deep in prose.
- Use relative links for in-repo docs.

## Audit script

Run the bundled checker:

```bash
ruby scripts/github_readme_audit.rb README.md
```

Strict mode (stronger section expectations):

```bash
ruby scripts/github_readme_audit.rb README.md --strict
```

The script checks for:

- H1 presence
- Core onboarding sections (installation, usage/quickstart)
- License section
- Command code blocks for setup/use
- Intro length guardrail
- Optional table-of-contents reminder on very long files

## Output expectations

When using this skill for a user task:

1. Return the revised README content.
2. Summarize what changed in onboarding flow.
3. Note any missing information that requires user input (for example, deployment steps or support policy).
