# Handouts evals

Three fixed-input cases: a research reading handout, a flight comparison, and a race-day reference pack. Run each with the draft skill and without it before cross-provider testing. Use the same inputs and prompt for each pair. Keep run outputs and production intermediates in `/tmp/handouts-workspace/`, not the Inbox or repository.

## Fixtures and privacy

- **Tart cherry:** research notes from a previous session, reviewed for personal names and identifying details. These are frozen research inputs, not a claim that the studies have been freshly verified.
- **Flights:** fully invented Singapore–Boston–Grand Junction itineraries, travelers, schedules, and prices. No original itinerary data, booking evidence, links, QR destinations, or personal details are included. Airline codes are familiar examples; schedules are not real quotes. Agents should not add a fictional-data disclaimer to the handout unless the task requests one: provenance belongs here, not in editorial boilerplate.
- **Race:** small, fabricated Japanese PDFs for an invented Kirigaoka event, town, rider, and team. No original JBCF pages, maps, contact details, passes, or rider lists are included. The PDFs exercise translation, map inclusion, schedule preservation, and print-only document handling.

## Writing-model workflow

For with-skill runs, allow the handout agent to delegate to its required Opus writer. The iteration-1 harness prohibited all subagents; do not reuse that restriction for the revised skill. Keep the source inputs and task prompts identical across configurations, but allow the skill's workflow to differ from the baseline.

Record the model-discovery result, selected exact provider/model ID, writer launch, and writer text artifact. Check `workflow_assertions` in `evals.json` separately from PDF-content grades; these requirements apply only to with-skill runs, not to an unconstrained baseline. If the latest available `meridian/claude-opus*` cannot be discovered or launched, record a blocked run rather than substituting a model. Cross-provider tests vary the parent/layout model while holding the required writing route constant; record both models.

## What counts as good

Human review is the primary quality gate. Review at physical A4 size and in grayscale, not only zoomed on screen:

- Is it comfortable to read, with a clear hierarchy and sensible page breaks?
- Can the reader compare options or find the next action quickly? Preserve useful tables; in the research case, compare use cases, doses, and timing side by side rather than flattening them into prose.
- Does every main-content heading, table, calendar, figure, and caption stay inside the prose column? Nothing may spill or span into the gutter or sidebar, even if it does not clip at the page edge. Preserve useful tables by wrapping or splitting them, not by discarding them or making them tiny.
- Does the sidebar offer real handwriting space rather than becoming a second packed column?
- Do graphics explain something, sit beside the relevant content, and remain legible? Use the skill's default navy/amber/blue/green/neutral palette as a starting point when color is useful; it comes from Nate's preferred round-2 baseline flight comparison. Check that categories stay consistent and that labels or other cues preserve meaning in grayscale; do not impose color on every document.
- Does it contain the requested information without repetition or unsolicited boilerplate?

Programmatic checks support that judgment: PDF page dimensions, embedded fonts, extracted text, costs/deadlines, intact pages, and unchanged pit-pass bytes. Check A4 dimensions on every composed page; switching to A3 without approval is a failure, not a layout adaptation. Column-boundary checks must cover entire table/figure extents, not just extracted text. Prose line-length samples and footer-region text are diagnostics, not infallible classifiers: table cells, captions, included source pages, and paragraph endings need separate treatment. The skill permits font fallbacks and task-appropriate layouts; an exact-font or portrait-only assertion would contradict that contract.

Source uncertainty is not disposable boilerplate. In the research case, explaining why a 4.8x label cannot establish a study-equivalent dose is part of the answer.

Do not finalize the skill from automated pass rates alone. After Nate accepts the visual standard, test other models/providers, then conduct the issue's human-approved deletion cycles.
