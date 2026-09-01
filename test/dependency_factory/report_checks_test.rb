require "test_helper"
require_relative "../../tools/ci/dependency_factory"

class DependencyFactoryReportChecksTest < Minitest::Test
  ADVISORY = "https://github.com/cli/cli/security/advisories/GHSA-vfhh-p7hm-pxfh"
  NOTES = "https://github.com/cli/cli/releases/tag/v2.98.0"

  def test_a_complete_report_has_no_errors
    assert_empty errors_for(body)
  end

  def test_candidate_missing_from_every_table_is_reported
    errors = errors_for(body(skipped: skipped_rows.reject { |row| row.include?("pi-subagents") }))

    assert_includes errors, "pi:pi-subagents is a candidate but appears in no table"
    assert_includes errors, "pi:pi-subagents 0.63.0 is newer than the eligible release and must appear under Skipped candidates"
  end

  def test_boilerplate_and_patch_phrase_are_rejected_for_minor_bumps
    rows = update_rows(watchexec: "[Maintenance release with fixes.](https://example.test)")
    assert_includes errors_for(body(updates: rows)), "watchexec: Why must name a concrete benefit, not 'Maintenance release with fixes.'"

    rows = update_rows(watchexec: "[Patch release; staying current.](https://example.test)")
    assert_includes errors_for(body(updates: rows)), "watchexec: 'Patch release; staying current.' is only allowed for patch-level bumps"
  end

  def test_security_true_needs_an_advisory_link_or_a_quoted_excerpt
    rows = update_rows(gh: "[Fixes the forwarded-port vulnerability.](#{NOTES})")
    assert_includes errors_for(body(updates: rows)), "gh: Security true needs an advisory link or a quoted excerpt in its assessment"

    quoted = assessment("gh 2.98.0", "Security: upstream says “binds the local forwarded port to all available network interfaces by default”. Benefit: real. Irrelevant changes: none. Cost and risk: none. Recommendation: upgrade.")
    assert_empty errors_for(body(updates: rows, assessments: [quoted, *other_assessments].join("\n")))
  end

  def test_updates_must_match_the_diff_and_respect_the_release_gate
    rows = update_rows(gh_new: "2.99.0")
    errors = errors_for(body(updates: rows), changes: changes.merge("gh" => ["2.97.0", "2.99.0"]))

    assert_includes errors, "gh: 2.99.0 is newer than the eligible 2.98.0"
    assert_includes errors, "gh 2.99.0 was published 2026-09-01T20:25:04Z, inside the 3-day release gate"
    assert_includes errors_for(body, changes: changes.merge("jq" => ["1.8.2", "1.9.0"])), "jq changed in the diff without an Updates row"
    assert_includes errors_for(body, changes: changes.except("watchexec")), "watchexec: the diff does not change this pin to 2.7.0"
  end

  def test_snoozes_must_be_listed_and_left_alone
    assert_includes errors_for(body(snoozed: [])), "standard 1.56.0 is snoozed in config/dependency-updater.yml but missing from Snoozed candidates"
    assert_includes errors_for(body, changes: changes.merge("standard" => ["1.52.0", "1.56.0"])), "standard is snoozed but changed in the diff"
  end

  def test_every_reported_tool_needs_a_full_assessment
    errors = errors_for(body(assessments: assessment("gh 2.98.0", "Security: none. Benefit: none.")))

    assert_includes errors, "gh: assessment is missing Irrelevant changes:"
    assert_includes errors, "watchexec: Dependency assessments needs a bullet that starts with `watchexec <version>`"
  end

  private

  def errors_for(text, changes: self.changes)
    report = DependencyFactory::Report.new(text)
    DependencyFactory::RubricChecks.new(report: report).errors +
      DependencyFactory::ReportChecks.new(candidates: candidates, report: report, changes: changes, snoozes: snoozes).errors
  end

  def candidates
    {"generated_at" => "2026-09-01T22:00:00Z", "minimum_release_age_days" => 3, "candidates" => [
      candidate("gh", "2.97.0", "2.98.0", "2.99.0", "2.98.0" => "2026-08-20T22:15:58Z", "2.99.0" => "2026-09-01T20:25:04Z"),
      candidate("watchexec", "2.5.1", "2.7.0", "2.7.0", "2.7.0" => "2026-08-24T08:22:34Z"),
      candidate("pi:pi-subagents", "0.37.2", "0.37.2", "0.63.0", "0.63.0" => "2026-09-01T21:48:15Z"),
      {"name" => "Gemfile.lock", "kind" => "gem-lock", "current" => "2 gems behind", "eligible" => "regenerated", "latest" => "regenerated", "published" => {},
       "members" => [candidate("json", "2.18.0", "2.21.2", "2.21.2", "2.21.2" => "2026-08-10T00:00:00Z"), candidate("standard", "1.52.0", "1.56.0", "1.56.0", "1.56.0" => "2026-08-15T00:00:00Z")]}
    ]}
  end

  def candidate(name, current, eligible, latest, published)
    {"name" => name, "kind" => "mise", "current" => current, "eligible" => eligible, "latest" => latest, "published" => published}
  end

  def snoozes
    {"standard" => {"candidate" => "1.56.0", "wake_at" => "1.57.0"}}
  end

  def changes
    {"gh" => ["2.97.0", "2.98.0"], "watchexec" => ["2.5.1", "2.7.0"], "Gemfile.lock" => ["changed", "changed"], "json" => ["2.18.0", "2.21.2"]}
  end

  def update_rows(gh: "[Fixes the forwarded-port vulnerability.](#{ADVISORY})", gh_new: "2.98.0", watchexec: "[Skips watches in ignored directories.](https://github.com/watchexec/watchexec/releases/tag/v2.7.0)")
    ["| gh | 2.97.0 | #{gh_new} | true | #{gh} |", "| watchexec | 2.5.1 | 2.7.0 | false | #{watchexec} |",
      "| Gemfile.lock | 2 gems behind | regenerated | false | [json 2.21.2 parses faster.](https://rubygems.org/gems/json/versions/2.21.2) |"]
  end

  def skipped_rows
    ["| gh | [2.99.0](https://github.com/cli/cli/releases/tag/v2.99.0) | false |", "| pi:pi-subagents | [0.63.0](https://www.npmjs.com/package/pi-subagents/v/0.63.0) | false |"]
  end

  def assessment(tool, text = "Security: none found. Benefit: real. Irrelevant changes: none. Cost and risk: none. Recommendation: upgrade.")
    "- `#{tool}`: #{text}"
  end

  def other_assessments
    ["watchexec 2.7.0", "Gemfile.lock", "pi:pi-subagents 0.63.0"].map { |tool| assessment(tool) }
  end

  def body(updates: update_rows, skipped: skipped_rows, snoozed: ["| standard | [1.56.0](https://rubygems.org/gems/standard/versions/1.56.0) | false |"], assessments: nil)
    assessments ||= [assessment("gh 2.98.0"), *other_assessments].join("\n")
    <<~MARKDOWN
      ## Updates

      | Tool | Old | New | Security | Why |
      |------|-----|-----|----------|-----|
      #{updates.join("\n")}

      ## Skipped candidates

      | Tool | Candidate | Security |
      |------|-----------|----------|
      #{skipped.join("\n")}

      ## Snoozed candidates

      | Tool | Candidate | Security |
      |------|-----------|----------|
      #{snoozed.join("\n")}

      ## Dependency assessments

      #{assessments}
    MARKDOWN
  end
end
