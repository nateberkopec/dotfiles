---
name: deep-research
description: This skill should be used when users request comprehensive, in-depth research on a topic that requires detailed analysis similar to an academic journal or whitepaper. The skill conducts multi-phase research using web search and content analysis, employing high parallelism with multiple subagents, and produces a detailed markdown report with citations.
license: MIT
---

# Deep Research

This skill conducts comprehensive research on complex topics using a multi-agent architecture, producing detailed reports similar to academic journals or whitepapers.

## Purpose

The deep-research skill transforms broad research questions into thorough, well-cited reports using a three-agent system:

1. **Lead Agent (You)**: Conducts interviews, plans research, orchestrates subagents
2. **Researcher Agents**: Execute web searches and save findings to files
3. **Report-Writer Agent**: Synthesizes research notes into final report

## When to Use This Skill

Use this skill when the user requests:
- In-depth research on a complex topic
- A comprehensive report or analysis
- Research that requires multiple sources and synthesis
- Deep investigation similar to academic or whitepaper standards
- Detailed analysis with proper citations

Do NOT use this skill for:
- Simple fact-finding queries
- Single-source information lookup
- Code-only research within repositories
- Quick exploratory searches

## Agent Architecture

### Lead Agent (You - the Orchestrator)

**Role**: Interview user, plan research threads, spawn and coordinate subagents

**Tools allowed**: Task (to spawn subagents), AskUserQuestion, Write (for research plan only)

**Responsibilities**:
- Conduct user interview to scope research
- Perform initial reconnaissance
- Decompose topic into 10+ research threads
- Spawn researcher agents in parallel
- Spawn report-writer agent after research completes

### Researcher Agents

**Role**: Execute focused research on assigned subtopic

**Tools allowed**: WebSearch, WebFetch, Write

**Responsibilities**:
- Search the web for information on assigned topic
- Fetch and analyze relevant pages
- Save structured research notes to `research_notes/` directory

**Output format**: Each researcher saves a markdown file to `research_notes/[subtopic-slug].md` with:
- Summary of findings
- Key facts and data points
- Source URLs with brief descriptions
- Notable quotes or excerpts
- Conflicts or gaps identified

### Report-Writer Agent

**Role**: Synthesize all research notes into final report

**Tools allowed**: Read, Glob, Write

**Responsibilities**:
- Read all files from `research_notes/` directory
- Identify themes, patterns, and conflicts across sources
- Structure and write the final report
- Create the sources bibliography

## Research Process

### Phase 1: Interview and Scope Definition

Start by interviewing the user to understand their research needs. Ask questions about:

1. **Research objectives**: What are they trying to understand or decide?
2. **Depth and breadth**: How comprehensive should the research be?
3. **Target audience**: Who will read this report?
4. **Key questions**: What specific questions need answering?
5. **Time constraints**: Is this time-sensitive information?
6. **Scope boundaries**: What should be explicitly included or excluded?

The interview should be thorough but efficient. Use the AskUserQuestion tool to gather this information in 2-3 rounds of questions maximum.

### Phase 2: Initial Reconnaissance

After the interview, perform initial reconnaissance to identify the research landscape:

1. Conduct 3-5 broad web searches to map the topic space
2. Identify key subtopics, domains, and areas of focus
3. Note promising sources, authoritative voices, and research gaps
4. Create a research plan outlining 10+ specific research threads

Save the research plan to `research_plan.md` documenting:
- The research threads identified
- Which researcher will handle each thread
- Expected output from each researcher

### Phase 3: Parallel Research (Researcher Agents)

Launch 10+ researcher agents in parallel using the Task tool. Each agent receives a focused research assignment.

**Spawning researcher agents:**

```
Task tool with:
- subagent_type: "general-purpose"
- prompt: Include these elements:
  1. Clear statement: "You are a RESEARCHER agent"
  2. Specific subtopic assignment
  3. Tool restrictions: "Only use WebSearch, WebFetch, and Write tools"
  4. Output instructions: "Save your findings to research_notes/[subtopic].md"
  5. Format requirements for the research notes file
```

**Example researcher prompt:**
```
You are a RESEARCHER agent investigating: "Technical implementation of quantum error correction"

YOUR TOOLS: Only use WebSearch, WebFetch, and Write.

TASK:
1. Use WebSearch to find authoritative sources on quantum error correction implementation
2. Use WebFetch to extract detailed information from promising sources
3. Save your findings to research_notes/quantum-error-correction.md

OUTPUT FORMAT (save to research_notes/quantum-error-correction.md):
# Quantum Error Correction Implementation

## Summary
[2-3 paragraph summary of key findings]

## Key Findings
- [Bullet points of important facts, data, techniques]

## Sources
1. [URL] - [Brief description of what this source contributed]
2. [URL] - [Brief description]
...

## Notable Quotes
> "[Relevant quote]" - Source

## Gaps and Conflicts
- [Any conflicting information or areas needing more research]
```

**Launch all researcher agents in a single message** with multiple Task tool calls for true parallelism.

### Phase 4: Report Generation (Report-Writer Agent)

After all researcher agents complete, spawn a single report-writer agent:

**Spawning the report-writer agent:**

```
Task tool with:
- subagent_type: "general-purpose"
- prompt: Include these elements:
  1. Clear statement: "You are a REPORT-WRITER agent"
  2. Tool restrictions: "Only use Read, Glob, and Write tools"
  3. Instructions to read all files from research_notes/
  4. Report structure requirements
  5. Output file paths for report and sources
```

**Example report-writer prompt:**
```
You are a REPORT-WRITER agent synthesizing research findings into a final report.

YOUR TOOLS: Only use Read, Glob, and Write.

TASK:
1. Use Glob to list all files in research_notes/
2. Use Read to load each research notes file
3. Synthesize findings into a comprehensive report
4. Write the final report to [topic]-report.md
5. Write the sources bibliography to [topic]-sources.md

REPORT STRUCTURE:
- Executive Summary (2-3 paragraphs)
- [Adaptive middle sections based on topic]
- Critical Analysis
- Conclusions
- References (numbered citations)

SOURCES FILE STRUCTURE:
# Research Sources for [Topic]

## [1] Source Title
- **URL**: [url]
- **Accessed**: [date]
- **Type**: [Academic paper / Blog post / Documentation / News article]
- **Key Points**: [bullet points]
- **Relevance**: [why this source matters]

WRITING GUIDELINES:
- Use numbered citations [1], [2], etc.
- Cross-reference findings across multiple researcher notes
- Note any conflicts or gaps in the research
- Use clear, precise academic language
- Include tables for comparisons where appropriate
```

### Phase 5: Output and Summary

After the report-writer completes:

1. Inform the user of the generated files:
   - `[topic]-report.md`: Main research report
   - `[topic]-sources.md`: Complete bibliography
   - `research_notes/`: Directory of raw research (can be deleted)

2. Provide a brief verbal summary of key findings

3. Offer to answer follow-up questions or expand on any section

## File Structure

```
./
├── research_plan.md           # Your research plan (Phase 2)
├── research_notes/            # Researcher agent outputs (Phase 3)
│   ├── subtopic-1.md
│   ├── subtopic-2.md
│   └── ...
├── [topic]-report.md          # Final report (Phase 4)
└── [topic]-sources.md         # Bibliography (Phase 4)
```

## Logging and Observability

Track research progress by documenting in `research_plan.md`:

1. **Research threads assigned**: List each subtopic and its researcher
2. **Status tracking**: Note when each researcher completes
3. **Issues encountered**: Document any gaps or conflicts found

This provides transparency into the research process and helps with debugging or expanding research later.

## Best Practices

### Agent Separation

- **Lead agent**: ONLY spawns agents and coordinates - no direct research
- **Researchers**: ONLY search, fetch, and write notes - no synthesis
- **Report-writer**: ONLY reads notes and writes report - no new research

This separation ensures clean handoffs and reproducible results.

### Research Quality

- Prioritize authoritative, recent sources (especially for time-sensitive topics)
- Cross-reference claims across multiple researcher notes
- Note conflicting information or perspectives
- Distinguish between facts, expert opinions, and speculation
- Be transparent about limitations in available information

### Efficiency

- Launch all researcher agents truly in parallel (single message, multiple Task tool calls)
- Use model="haiku" for researcher agents to reduce costs
- Use model="sonnet" for report-writer agent for better synthesis
- Clear task delineation prevents redundant research

## Common Patterns

### Comparative Research
When comparing technologies, approaches, or solutions:
- Assign one researcher per option being compared
- Assign one researcher for cross-cutting concerns (performance, cost, etc.)
- Report-writer creates comparison tables

### Technical Deep-Dives
When researching technical topics:
- Assign researchers to: fundamentals, implementation, case studies, limitations
- Report-writer structures from basics to advanced

### Market/Landscape Research
When surveying a domain or market:
- Assign researchers to: major players, emerging players, trends, analysis firms
- Report-writer categorizes and evaluates the landscape

### Historical/Evolution Research
When investigating how something developed:
- Assign researchers to different time periods or key events
- Report-writer creates timeline and connects to present
