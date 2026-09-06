require "test_helper"
require_relative "../../tools/ci/dependency_factory"

class DependencyFactoryReportChecksTest < Minitest::Test
  def test_complete_decisions_pass_without_prescribed_prose
    assert_empty errors
    assert_empty errors(prose: "## Whatever is useful\nAn explanation, not a table.\n")
  end

  def test_malformed_and_duplicate_ledgers_fail_closed
    ["", "[]", "null", "{", '{"decisions":{},"outcome":"ready"}'].each do |json|
      refute_empty DependencyFactory::Report.new("<!-- dependency-decisions\n#{json}\n-->").errors
    end
    assert_includes errors(rows: rows + [rows.first]), "Duplicate decisions"
  end

  def test_missing_or_invented_decisions_are_rejected
    assert_includes errors(rows: rows.drop(1)), "gh 2.98.0: missing decision"
    assert_includes errors(rows: rows + [rows.first.merge("version" => "3.0.0")]), "gh 3.0.0: not a candidate"
  end

  def test_decisions_match_diff_and_eligible_publication
    assert_includes errors(changes: {}), "gh 2.98.0: decision disagrees with diff"
    assert_includes errors(changes: {"gh" => ["2.97.0", "2.99.0"]}), "gh: 2.99.0 outside eligible range"
    assert_includes errors(changes: {"gh" => ["2.97.0", "2.97.1"]}), "gh: 2.97.1 has no eligible publication date"
    assert_includes errors(changes: {"gh" => ["2.96.0", "2.98.0"]}), "gh: old pin disagrees with baseline"
  end

  def test_lock_batch_cannot_hide_unknown_or_new_transitive_gems
    assert_includes errors(changes: {"Gemfile.lock" => ["changed", "changed"], "new-gem" => [nil, "1.0"]}), "new-gem: changed but not a candidate; refresh discovery"
  end

  def test_security_requires_collected_source_and_exact_quote
    security = rows.first.merge("security" => true, "quote" => "Stops exposing forwarded ports.")
    assert_empty errors(rows: [security, rows.last])
    assert_includes errors(rows: [security.merge("quote" => "Invented claim about secrets"), rows.last]), "gh 2.98.0: security requires an exact collected quote"
    assert_includes errors(rows: [security.merge("source" => "https://evil.test/security/advisories/fake"), rows.last]), "gh 2.98.0: source is not collected evidence"
  end

  def test_snooze_requires_verified_advisory_and_never_bypasses_age_gate
    snoozes = {"gh" => {"candidate" => "2.98.0", "wake_at" => "3.0.0", "reason" => "Wait for regression fix"}}
    assert_includes errors(snoozes: snoozes), "gh: snoozed until 3.0.0"
    security = rows.first.merge("security" => true, "quote" => "Stops exposing forwarded ports.", "source" => "https://example.test/security/advisories/gh")
    assert_empty errors(rows: [security, rows.last], snoozes: snoozes, source: security["source"])
  end

  private

  def rows
    %w[2.98.0 2.99.0].map do |version|
      {"name" => "gh", "version" => version, "action" => (version == "2.98.0") ? "update" : "defer",
       "reason" => "Useful fix or wait for the age gate", "source" => "https://example.test/#{version}", "security" => false}
    end
  end

  def errors(rows: self.rows, changes: {"gh" => ["2.97.0", "2.98.0"]}, snoozes: {}, prose: "", source: "https://example.test/2.98.0")
    candidate = {"name" => "gh", "kind" => "mise", "current" => "2.97.0", "eligible" => "2.98.0", "latest" => "2.99.0", "source" => "https://example.test/2.99.0", "published" => {"2.98.0" => "2026-08-20T00:00:00Z", "2.99.0" => "2026-09-01T00:00:00Z"}}
    data = {"generated_at" => "2026-09-01T22:00:00Z", "minimum_release_age_days" => 3, "candidates" => [candidate]}
    notes = {"packages" => {"gh" => [{"version" => "2.98.0", "url" => source, "text" => "Stops exposing forwarded ports."}]}}
    text = "#{prose}<!-- dependency-decisions\n#{JSON.generate("outcome" => "ready", "decisions" => rows)}\n-->"
    DependencyFactory::ReportChecks.new(candidates: data, report: DependencyFactory::Report.new(text), changes: changes, snoozes: snoozes, notes: notes).errors
  end
end
