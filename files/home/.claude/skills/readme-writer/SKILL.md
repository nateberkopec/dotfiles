---
name: readme-writer
description: Write READMEs for software projects. The skill should be used when writing or revising a README or README.md file.
license: MIT
---

The general flow of a README:

1. A section describing what the package does and why it's important (i.e. "what's in it for me" for the user)
2. A section on how to install and use the package
3. A section on common configuration options and methods
4. A section on how to contribute or pointer to CONTRIBUTING.md, notes on the developer's build environment and potential portability problems.
5. a brief explanation of any unusual top-level directories or files, or other hints for readers to find their way around the source;

### Github-flavored markdown

Since most all of my projects are Github, you have have some neat markdown block extensions available:

> [!CAUTION]
> [!IMPORTANT]
> [!NOTE]
> [!TIP]
> [!WARNING]

Use these to call out any semantic sections.

### Reading level

I prefer a Fleisch-Kincaid reading level of 9th grade or below. Revise the README until it is below a 9th grade level. Use `scripts/flesch_kincaid.rb`.

### ESL audience

Many of the people reading a software project README are not native speakers of English.

`scripts/top1000.txt` is available for profiling what % of a text's words are in the top 1000 most common in English. Aim to increase this number.

DO use active voice where possible.
DON'T assume passive constructions are easy just because the words are simple.
DO keep noun phrases short and direct.
DON'T stack multiple modifiers before nouns ("the recently revised standardized testing protocol").
DO limit embedded clauses—one level of nesting is usually manageable.
DON'T assume simple vocabulary guarantees comprehension; "The man who the dog that bit the cat chased ran away" uses basic words but is notoriously hard to parse.
DO use conditionals sparingly, favoring simple "if/then" structures.
DON'T rely heavily on mixed or inverted conditionals ("Had she known...").
DO make logical connections explicit with transition words (however, therefore, because).
DON'T expect readers to infer relationships between ideas.
DO spread information across multiple sentences when needed.
DON'T pack too many new concepts into a single sentence.
DO explain or gloss cultural references.
DON'T assume shared background knowledge about idioms, historical events, or cultural touchstones.

### Bibliography

— GNU Coding Standards, https://www.gnu.org/prep/standards/html_node/Releases.html#i... (July 1, 2021)
— Software Release Practice HOWTO, https://tldp.org/HOWTO/Software-Release-Practice-HOWTO/distp... (Revision 4.1)
