---
name: handouts
description: Compose and typeset polished PDFs for personal reading on paper. Use when asked for a handout, reading packet, printable report, comparison brief, or one-page guide, including research reports and existing text needing layout. Existing PDFs that only need printing belong to the printing skill instead.
---

# Handouts

Make a document the reader can comfortably read, compare, annotate, or use beside the task. Own composition, typography, graphics placement, PDF production, and validation; choose any available production toolchain.

## Writing

Delegate all authored handout text to a subagent using the latest available Opus model from the `meridian` provider (`meridian/claude-opus*`; the registry uses the `claude-` prefix). Discover available models at runtime and choose the newest Opus version, rather than pinning a version or substituting another provider. If that model or delegation is unavailable, stop and ask the user; do not silently write the text yourself.

Give the writer the source material, task constraints, and composition guidance below. Its remit includes prose, headings, sidenotes, captions, table labels, and translations. Keep unchanged source pages intact. The parent owns layout, graphics, PDF production, and validation; send needed wording changes back to the writer rather than rewriting its copy during typesetting.

## Composition

Follow the task's content, condensation, page-count, and reading-time constraints. There is no default compression or length target. Preserve comfortable type size rather than shrinking text to force a page count; change composition instead.

Omit citation lists, reference apparatus, unsolicited qualifications, and editorial boilerplate unless requested. Preserve substantive uncertainty or limitations already in the source when removing them would change its meaning. Do not invent facts to fill layout space.

Use tables when repeated facts or choices are easier to scan side by side: protocols, doses, timings, schedules, costs, or trade-offs. Preserve useful tabular structure from the source; a prose-first layout is not a reason to turn a helpful comparison into paragraphs. Keep explanatory prose where it adds context.

Use illustrations when they materially improve understanding, not as decoration. Put graphics beside the relevant prose and make labels readable at physical print size. Existing maps, forms, and schedule pages can be included intact when the task benefits; do not re-typeset documents that only need printing.

### Default color palette

Use this restrained palette when color helps distinguish meaningful categories or guide comparison. It is a starting point, not a reason to color every element:

| Role | Hex |
|---|---|
| Ink / headings | `#193047` |
| Secondary text | `#526273` |
| Amber category fill | `#F5D69B` |
| Blue category fill | `#BBD9EE` |
| Green category fill | `#BFE6D0` |
| Neutral fill | `#ECEEF0` |

Use dark text on the light fills. In travel calendars, amber can mark travel, blue the first destination, green the second, and neutral home; use consistent meanings within each document. Preserve meaning in grayscale with text labels, outlines, patterns, or other non-color cues. Never rely on hue alone, and check legibility at physical print size.

## Page layout

Default to A4 portrait: a main prose column plus a sparse outer sidenote/handwriting column. Keep the sidebar on the right; mirror it for an explicitly duplex layout.

Target about 70 characters per full prose line, accepting roughly 60–80 including spaces and punctuation. Measure actual rendered text, not just CSS or nominal geometry. Short paragraph endings are normal. At Palatino 11 pt, a starting grid is 18 mm left margin, 121 mm prose, 7 mm gutter, 46 mm sidebar, and 18 mm right margin. Adjust for the actual font and content while keeping useful writing space.

Treat the prose-column boundary as a hard limit: main-content text, headings, tables, calendars, figures, and captions must never enter the gutter or sidenote column. No full-width or cross-column spans, even when the sidebar is otherwise empty. Align deliberately placed sidenotes and small sidebar graphics with the prose they explain; leave useful handwriting space. Sidenotes have no headers or horizontal rules.

Make wide tables fit by wrapping cells, splitting them into linked narrower tables, or continuing across pages with repeated headers—not by extending into the sidebar or shrinking type until it is hard to read. Ask the Opus writer for any changed labels or wording. Use A4 landscape when appropriate, retaining a separate sidebar and the same hard column boundary. Do not switch to A3 or another paper size to rescue a layout without explicit user approval. Unchanged source PDF pages retain their original geometry.

No footers, including page-number footers. No eyebrows (small labels above titles or headings).

## Typography

Verify the actual rendered fonts; adjust measure if a fallback is used:

- Serif: Palatino → serif.
- Sans-serif: Helvetica Neue → sans-serif.
- Code: Inconsolata → Menlo → monospace.

Do not add Source Serif or Source Sans. Use a 3 pt spacing unit:

| Element | Font | Size / line height | Space before / after |
|---|---|---|---|
| Title | Palatino, regular | 26 / 30 pt | 0 / 15 pt |
| Heading 1 | Helvetica Neue | 17 / 21 pt | 24 / 9 pt |
| Heading 2 | Helvetica Neue | 13 / 18 pt | 18 / 6 pt |
| Heading 3 | Helvetica Neue, bold | 11 / 15 pt | 15 / 3 pt |
| Body | Palatino | 11 / 15 pt | 0 / 6 pt between paragraphs |
| Sidenotes and captions | Helvetica Neue | 9 / 12 pt | As needed in 3 pt increments |
| Code | Inconsolata, with listed fallbacks | 10 / 15 pt | 9 / 9 pt around blocks |

Body text is ragged-right. Keep headings with following text, and suppress unnecessary heading spacing at page tops. Adapt defaults when appropriate while retaining readable hierarchy and consistent vertical rhythm.

## Validate and deliver

Render and visually inspect every page. Revise clipping, overflow, awkward breaks, stranded headings, tiny tables, illegible or cropped graphics, and poorly balanced whitespace. Check every table, calendar, figure, heading, and caption against the actual prose-column boundary; page-edge clipping checks alone will miss overflow into the sidebar. Reject cross-column spans. Check that the sidebar still offers writing space, graphics remain adjacent to relevant content, and there are no footers, eyebrows, sidenote headers, or sidenote rules on composed pages.

Verify page dimensions, requested length, actual font rendering/embedding, and representative full prose line lengths. Suitable tools include `pdfinfo`, `pdffonts`, `pdftotext -bbox-layout`, and `pdftoppm`; equivalent tools are fine. Inspect included source pages too, but do not erase their original labels or numbering merely to match composed-page styling.

Keep intermediate files in temporary storage. Deliver a PDF with a descriptive filename in `~/Documents/Inbox` unless another destination was requested.

Physically print only when requested. Hand the finished artifact and any unchanged print-only source documents to the existing printing skill; it owns printer discovery, options, submission, queues, and troubleshooting.
