---
name: deep-research
description: This skill should be used when users request comprehensive, in-depth research on a topic that requires detailed analysis similar to an academic journal or whitepaper. The skill conducts multi-phase research using web search and content analysis, employing high parallelism with multiple subagents, and produces a detailed markdown report with citations.
license: MIT
---

# Deep Research

This skill conducts comprehensive research on complex topics, producing detailed reports similar to academic journals or whitepapers.

## Purpose

The deep-research skill transforms broad research questions into thorough, well-cited reports by:

1. Conducting structured interviews to understand research goals
2. Performing iterative deepening to identify key areas
3. Launching parallel research subagents for comprehensive coverage
4. Synthesizing findings into a cohesive, academically-styled report
5. Maintaining a separate bibliography with all sources

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

### Phase 2: Initial Reconnaissance (Iterative Deepening)

After the interview, perform initial reconnaissance to identify the research landscape:

1. Conduct 3-5 broad web searches to map the topic space
2. Identify key subtopics, domains, and areas of focus
3. Note promising sources, authoritative voices, and research gaps
4. Create a research plan outlining 10+ specific research threads

This phase should be relatively quick (5-10 searches) but strategic. The goal is to create an informed plan for the parallel exploration phase.

Document findings in working notes but do not create the final report yet.

### Phase 3: Parallel Exploration (High Parallelism)

Launch 10+ parallel research subagents using the Task tool with subagent_type="general-purpose". Each agent should investigate a specific research thread identified in Phase 2.

**Agent assignment strategy:**
- Assign each agent a focused research question or subtopic
- Ensure agents have clear, non-overlapping objectives
- Instruct agents to use WebSearch and WebFetch tools extensively
- Request that each agent return structured findings with sources

**Example agent tasks:**
- "Research the technical implementation of [specific approach]"
- "Investigate the historical context and evolution of [topic]"
- "Compare and contrast [approach A] vs [approach B]"
- "Analyze the current state of research on [subtopic]"
- "Identify key challenges and limitations in [area]"

Launch all agents in parallel (in a single message with multiple Task tool calls) for maximum efficiency.

### Phase 4: Synthesis and Report Generation

After all subagents complete:

1. Review all findings from the parallel research phase
2. Identify common themes, conflicts, and key insights
3. Structure the report using a hybrid format (see below)
4. Write the report with academic rigor and proper citations
5. Create a separate sources bibliography file

**Report structure (hybrid format):**

The report should always include these core sections:
- **Executive Summary**: 2-3 paragraph overview of key findings
- **[Adaptive Middle Sections]**: Structure based on topic (comparisons, historical analysis, technical deep-dives, etc.)
- **Critical Analysis**: Deep evaluation, synthesis, and interpretation
- **Conclusions**: Summary of findings and implications
- **References**: Numbered citations used throughout

The middle sections should adapt to the research topic:
- For comparative research: Side-by-side analysis sections
- For technical topics: Architecture, implementation, tradeoffs sections
- For historical topics: Timeline, evolution, impact sections
- For survey research: Landscape, categories, evaluation sections

**Citation style:**
- Use numbered citations in the text: [1], [2], etc.
- Include inline source context when relevant: "According to Smith et al. [3], ..."
- Maintain a complete references section at the end
- Create a separate `sources-bibliography.md` file with full source details

### Phase 5: Output

Save two files in the current working directory:

1. **[topic-name]-report.md**: The main research report
2. **[topic-name]-sources.md**: Complete bibliography with:
   - Full URLs
   - Access dates
   - Source descriptions
   - Key excerpts or quotes
   - Relevance notes

Use clear, descriptive filenames based on the research topic (e.g., "quantum-computing-hardware-report.md").

Inform the user of the file locations and provide a brief summary of the research findings.

## Best Practices

### Research Quality

- Prioritize authoritative, recent sources (especially for time-sensitive topics)
- Cross-reference claims across multiple sources
- Note conflicting information or perspectives
- Distinguish between facts, expert opinions, and speculation
- Be transparent about limitations in available information

### Writing Style

- Use clear, precise academic language
- Define technical terms and acronyms on first use
- Provide context and background for complex concepts
- Use structured formatting (headers, lists, tables) for readability
- Include data, statistics, and concrete examples where relevant

### Source Management

- Maintain meticulous source tracking throughout research
- Cite sources immediately when incorporating information
- Prefer primary sources over secondary when possible
- Include diverse perspectives and sources
- Verify critical claims across multiple sources

### Efficiency

- Launch agents truly in parallel (single message, multiple tool calls)
- Use model="haiku" for subagents when appropriate for cost savings
- Avoid redundant research between agents through clear task delineation
- Work iteratively: reconnaissance → parallel research → synthesis

## Common Patterns

### Comparative Research
When comparing technologies, approaches, or solutions:
1. Research each option thoroughly in parallel
2. Create structured comparison sections (features, performance, costs, tradeoffs)
3. Use tables for side-by-side comparisons
4. Provide clear recommendations or trade-off analysis

### Technical Deep-Dives
When researching technical topics:
1. Start with fundamentals and key concepts
2. Progress to implementation details and architecture
3. Cover real-world applications and case studies
4. Address limitations, challenges, and future directions

### Market/Landscape Research
When surveying a domain or market:
1. Categorize the landscape (player types, segments, approaches)
2. Profile key players or solutions
3. Identify trends and patterns
4. Analyze implications and future outlook

### Historical/Evolution Research
When investigating how something developed:
1. Establish timeline and key milestones
2. Identify driving forces and catalysts
3. Analyze impact and consequences
4. Connect historical context to current state

## References

Store detailed source information in the references file:

```markdown
# Research Sources for [Topic]

## [1] Source Title
- **URL**: https://example.com/article
- **Accessed**: 2025-11-13
- **Type**: Academic paper / Blog post / Documentation / News article
- **Key Points**:
  - Main finding or claim 1
  - Main finding or claim 2
- **Relevance**: Why this source matters to the research

## [2] Source Title
...
```

This allows the main report to remain clean while preserving full source details for verification and further research.
