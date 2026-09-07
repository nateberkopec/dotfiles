require "test_helper"
require_relative "../../tools/ci/dependency_factory"

class DependencyFactoryGemReportTest < Minitest::Test
  def test_compatible_gem_batch_can_leave_a_snoozed_member_behind
    assert_empty errors
  end

  def test_a_batch_row_does_not_hide_an_unreported_member
    assert_includes errors(text: body.lines.reject { |line| line.start_with?("| standard |") }.join), "standard 1.1.0: missing from Skipped candidates"
  end

  def test_gem_members_cannot_bypass_the_gate_or_snooze
    changes = {"Gemfile.lock" => ["changed", "changed"], "json" => ["1.0.0", "1.2.0"], "standard" => ["1.0.0", "1.1.0"]}
    assert_includes errors(changes: changes), "json: 1.2.0 must be newer than 1.0.0 and no newer than 1.1.0"
    assert_includes errors(changes: changes), "standard: snoozed until 1.3.0"
  end

  def test_native_resolver_can_add_a_transitive_gem
    assert_empty errors(changes: changes.merge("new-transitive" => [nil, "1.0.0"]))
  end

  def test_no_batch_row_is_required_when_every_member_is_skipped
    text = body.lines.reject { |line| line.start_with?("| Gemfile.lock |", "- [Faster JSON]") }.join
      .sub("## Release notes\n", "## Release notes\n\nNo noteworthy changes.\n")
      .sub("Validation:", "| json | [1.1.0](https://example.test/json) | Resolver conflict. |\n\nValidation:")
    assert_empty errors(text: text, changes: {})
  end

  private

  def changes
    {"Gemfile.lock" => ["changed", "changed"], "json" => ["1.0.0", "1.1.0"]}
  end

  def errors(text: body, changes: self.changes)
    members = %w[json standard].map do |name|
      {"name" => name, "kind" => "gem", "current" => "1.0.0", "eligible" => "1.1.0", "latest" => "1.2.0",
       "published" => {"1.1.0" => "2026-08-01T00:00:00Z", "1.2.0" => "2026-09-01T00:00:00Z"}}
    end
    batch = {"name" => "Gemfile.lock", "current" => "2 gems behind", "members" => members}
    data = {"generated_at" => "2026-09-01T22:00:00Z", "minimum_release_age_days" => 3, "candidates" => [batch]}
    notes = {"packages" => {"json" => [{"version" => "1.1.0", "url" => "https://example.test/json"}]}}
    snoozes = {"standard" => {"candidate" => "1.1.0", "wake_at" => "1.3.0"}}
    DependencyFactory::ReportChecks.new(candidates: data, report: DependencyFactory::Report.new(text), changes: changes, snoozes: snoozes, notes: notes).errors
  end

  def body
    <<~MARKDOWN
      ## Release notes

      - [Faster JSON](https://example.test/json)

      ## Updates

      | Tool | Old | New |
      |------|-----|-----|
      | Gemfile.lock | 2 gems behind | [regenerated](https://example.test/json) |

      ## Skipped candidates

      | Tool | Candidate | Reason |
      |------|-----------|--------|
      | json | [1.2.0](https://example.test/json) | Wait until 2026-09-04T00:00:00Z. |
      | standard | [1.1.0](https://example.test/standard) | Snoozed until 1.3.0. |
      | standard | [1.2.0](https://example.test/standard) | Wait until 2026-09-04T00:00:00Z; snoozed until 1.3.0. |

      Validation: tests passed.
    MARKDOWN
  end
end
