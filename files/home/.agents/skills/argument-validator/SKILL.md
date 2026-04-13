---
name: argument-validator
description: This skill should be used when users want to validate or critique an argument by extracting premises, surfacing hidden assumptions, checking logical validity, optionally formalizing in Lean, and researching premise support.
license: MIT
---

# Argument Validator

## Overview

Provide a repeatable workflow for turning informal arguments into formal structure, identifying key assumptions, and checking validity and soundness with optional Lean formalization.

## When to Use

Use this skill when the user asks to:
- Validate or critique an argument
- Formalize an argument in logic or Lean
- Identify hidden assumptions or missing premises
- Test an argument with counterexamples
- Research whether premises are supported by evidence

Do not use this skill for:
- Simple opinion questions without an argument
- Purely stylistic rewrites
- Codebase-only reasoning tasks

## Workflow

### 1. Clarify Goal and Scope

Ask for missing information before formalization:
- Request the full argument text, conclusion, and intended audience
- Ask for definitions of ambiguous terms and the domain of discourse
- Ask whether the user wants logical validity, empirical soundness, or both

### 2. Extract Argument Structure

Restate the argument as a numbered list:
- Separate explicit premises from implicit assumptions
- Label each premise as logical, definitional, or empirical
- Note any ambiguous terms or scope shifts

### 3. Formalize the Logic

Translate into a precise formal representation:
- Choose the smallest logic that fits (propositional or first-order)
- Define symbols and predicates explicitly
- Encode the argument as premises → conclusion
- Flag quantifier order and scope changes

### 4. Check Logical Validity

Attempt a derivation from premises to conclusion:
- Identify the first point where the proof fails
- Produce the minimal additional assumption needed for validity
- Provide a counterexample model when possible

### 5. Formalize in Lean (Optional)

When the user wants machine-checking, offload to a Lean formalizer:
- Check for Lean availability (`lean --version` or `~/.elan/bin/lean --version`)
- Use `lean --stdin` for quick checks when no project exists
- Ask the formalizer to return a compilable Lean snippet plus missing lemmas

### 6. Validate Assumptions with Research Agents

For each empirical or contestable assumption:
- Spawn one research subagent per assumption
- Provide the exact assumption and desired standard of evidence
- Require a summary, sources, and a confidence rating
- Run subagents in parallel when there are multiple assumptions

### 7. Synthesize the Final Analysis

Deliver a structured summary:
- Validity verdict (valid / invalid) with justification
- Soundness verdict (supported / unsupported / unknown)
- List of key assumptions and their evidence status
- Suggested revisions that would strengthen the argument

## Subagent Prompts

### Formalizer Agent (Logic + Lean)

Use a `general` subagent to formalize the argument:

```
You are a FORMALIZER agent.

INPUT:
- Argument text
- Extracted premises + conclusion
- Draft formalization (symbols and formulas)

TASK:
1. Tighten the formalization (minimal logic).
2. Identify missing premises or implicit assumptions.
3. Attempt a Lean formalization.
4. If proof fails, explain where and why.

OUTPUT:
- Refined formalization
- Lean theorem statement
- Lean proof sketch or error explanation
- List of missing assumptions
```

### Assumption Research Agents

Use one `general` subagent per assumption:

```
You are a RESEARCHER agent.

ASSUMPTION:
[insert assumption]

TASK:
1. Use available web tools to find supporting or refuting sources.
2. Summarize evidence with citations.
3. Rate confidence (low/medium/high).

OUTPUT:
- Evidence summary
- Source list with URLs
- Confidence rating
- Notes on conflicts or gaps
```

## Output Format

Provide results in this order:
1. Restated argument (premises → conclusion)
2. Formalization (symbols + formulas)
3. Validity analysis (proof gap or confirmation)
4. Lean check results (if performed)
5. Assumptions table (premise, type, evidence, status)
6. Recommendations or questions to resolve uncertainty
