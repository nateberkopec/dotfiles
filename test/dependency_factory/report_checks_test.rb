require "test_helper"
require_relative "../../tools/ci/dependency_factory"

class DependencyFactoryReportChecksTest < Minitest::Test
  def test_complete_report_passes
    assert_empty errors
  end

  def test_empty_report_explains_the_required_format
    assert_includes errors(text: ""), "Start with Release notes, Updates, and Skipped candidates in that order"
  end

  def test_missing_candidates_and_reasons_are_rejected
    assert_includes errors(text: body.sub(skipped, "")), "gh 2.99.0: missing from Skipped candidates"
    assert_includes errors(text: body.sub("Wait until 2026-09-04T00:00:00Z", "")), "Skipped candidates: every cell must be filled"
    assert_includes errors(text: body.sub("2026-09-04T00:00:00Z", "tomorrow")), "gh 2.99.0: Reason must include 2026-09-04T00:00:00Z"
  end

  def test_report_matches_actual_changes_and_rejects_missing_publication_dates
    assert_includes errors(changes: {}), "gh: New must match the diff"
    assert_includes errors(changes: changes.merge("jq" => ["1.8.0", "1.9.0"])), "jq: changed without an Updates row"
    assert_includes errors(changes: {"gh" => ["2.97.0", "2.97.1"]}), "gh: 2.97.1 has no eligible publication date"
  end

  def test_gated_updates_are_rejected
    assert_includes errors(changes: {"gh" => ["2.97.0", "2.99.0"]}), "gh: 2.99.0 must be newer than 2.97.0 and no newer than 2.98.0"
  end

  def test_snoozes_need_a_reason_and_block_updates
    snoozes = {"gh" => {"candidate" => "2.98.0", "wake_at" => "3.0.0"}}
    assert_includes errors(snoozes: snoozes), "gh: snoozed until 3.0.0"
    assert_includes errors(snoozes: snoozes), "gh 2.99.0: Reason must include 3.0.0"
    assert_empty errors(snoozes: {"gh" => {"candidate" => "2.97.1", "wake_at" => "2.98.0"}})
  end

  def test_sourced_security_advisory_wakes_a_snooze
    text = body + "\n## Attention\n\n- Security: `gh 2.98.0`: [Fixes forwarded ports.](https://github.com/cli/cli/security/advisories/GHSA-example)\n"
    assert_empty errors(text: text, snoozes: {"gh" => {"candidate" => "2.98.0", "wake_at" => "3.0.0"}})
  end

  def test_security_quotes_must_come_from_collected_notes
    text = body + "\n## Attention\n\n- Security: `gh 2.98.0`: [Fixes forwarded ports.](https://example.test/2.98.0) Upstream: \"Stops exposing forwarded ports.\"\n"
    assert_empty errors(text: text)
    assert_includes errors(text: text.sub("Stops exposing", "Invented claim about")), "gh 2.98.0: Security needs an advisory link or a linked quote from collected notes"
  end

  def test_highlights_must_come_from_an_upgraded_range
    assert_includes errors(text: body.sub("[Try worktrees!](https://example.test/2.98.0)", "[Try worktrees!](https://example.test/2.99.0)")), "Release notes: each highlight must link only to notes in an upgraded version range"
    assert_empty errors(text: body.sub("- [Try worktrees!](https://example.test/2.98.0)", "Routine updates only; no noteworthy changes."))
    assert_includes errors(text: body.sub("- [Try worktrees!](https://example.test/2.98.0)", "- [Try worktrees!](https://example.test/2.98.0)\n" * 6)), "Release notes needs up to five linked highlights, or a short no-highlights explanation"
  end

  def test_unavailable_notes_cannot_supply_a_highlight
    notes = {"packages" => {"gh" => [{"version" => "2.98.0", "url" => "https://example.test/2.98.0", "error" => "Notes unavailable"}]}}
    assert_includes errors(notes: notes), "Release notes: each highlight must link only to notes in an upgraded version range"
  end

  def test_security_bullets_need_an_explicit_package_and_version
    assert_includes errors(text: body + "\n## Attention\n- Security: fixes something.\n"), "Security bullets must identify `tool version`"
  end

  def test_unknown_sections_and_candidates_are_rejected
    assert_includes errors(text: body + "\n## Research\nUnnecessary prose.\n"), "Unexpected section: Research"
    assert_includes errors(text: body.sub("| gh | [2.99.0]", "| unrelated | [2.99.0]")), "unrelated 2.99.0: not a skipped candidate"
  end

  def test_scoped_package_tables_and_security_tolerate_safe_output_mentions
    name = "npm:@openai/codex"
    text = body.gsub("| gh |", "| npm:`@openai/codex` |")
    text += "\n## Attention\n- Security: `npm:`@openai/codex` 2.98.0`: [Fix.](https://example.test/2.98.0) \"Stops exposing forwarded ports.\"\n"
    assert_empty errors(text: text, changes: {name => ["2.97.0", "2.98.0"]}, name: name)
  end

  private

  def changes
    {"gh" => ["2.97.0", "2.98.0"]}
  end

  def errors(text: body, changes: self.changes, snoozes: {}, notes: nil, name: "gh")
    candidate = {"name" => name, "kind" => "mise", "current" => "2.97.0", "eligible" => "2.98.0", "latest" => "2.99.0", "published" => {"2.98.0" => "2026-08-20T00:00:00Z", "2.99.0" => "2026-09-01T00:00:00Z"}}
    data = {"generated_at" => "2026-09-01T22:00:00Z", "minimum_release_age_days" => 3, "candidates" => [candidate]}
    notes ||= {"packages" => {name => [{"version" => "2.98.0", "url" => "https://example.test/2.98.0", "text" => "Stops exposing forwarded ports."}]}}
    DependencyFactory::ReportChecks.new(candidates: data, report: DependencyFactory::Report.new(text), changes: changes, snoozes: snoozes, notes: notes).errors
  end

  def skipped
    "| gh | [2.99.0](https://example.test/2.99.0) | Wait until 2026-09-04T00:00:00Z |"
  end

  def body
    <<~MARKDOWN
      ## Release notes

      - [Try worktrees!](https://example.test/2.98.0)

      ## Updates

      | Tool | Old | New |
      |------|-----|-----|
      | gh | 2.97.0 | [2.98.0](https://example.test/2.98.0) |

      ## Skipped candidates

      | Tool | Candidate | Reason |
      |------|-----------|--------|
      #{skipped}

      Validation: tests passed.
    MARKDOWN
  end
end
