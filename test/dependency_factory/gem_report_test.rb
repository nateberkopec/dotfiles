require "test_helper"
require_relative "../../tools/ci/dependency_factory"

class DependencyFactoryGemReportTest < Minitest::Test
  def test_compatible_batch_can_leave_snoozed_member_behind
    assert_empty errors
  end

  def test_lock_row_does_not_hide_member_gate_or_snooze
    assert_includes errors(version: "1.2.0"), "json: 1.2.0 outside eligible range"
    assert_includes errors(extra: {"standard" => ["1.0.0", "1.1.0"]}), "standard: snoozed until 1.3.0"
  end

  private

  def errors(version: "1.1.0", extra: {})
    members = %w[json standard].map do |name|
      {"name" => name, "kind" => "gem", "current" => "1.0.0", "eligible" => "1.1.0", "latest" => "1.2.0", "source" => "https://example.test/#{name}",
       "published" => {"1.1.0" => "2026-08-01T00:00:00Z", "1.2.0" => "2026-09-01T00:00:00Z"}}
    end
    rows = members.flat_map do |pin|
      %w[1.1.0 1.2.0].map do |target|
        {"name" => pin["name"], "version" => target, "reason" => "Compatibility and age", "source" => pin["source"], "security" => false,
         "action" => (pin["name"] == "json" && target == version) ? "update" : "defer"}
      end
    end
    report = DependencyFactory::Report.new("<!-- dependency-decisions\n#{JSON.generate("outcome" => "ready", "decisions" => rows)}\n-->")
    data = {"generated_at" => "2026-09-01T22:00:00Z", "minimum_release_age_days" => 3, "candidates" => [{"members" => members}]}
    snoozes = {"standard" => {"candidate" => "1.1.0", "wake_at" => "1.3.0"}}
    changes = {"Gemfile.lock" => ["changed", "changed"], "json" => ["1.0.0", version]}.merge(extra)
    DependencyFactory::ReportChecks.new(candidates: data, report: report, changes: changes, snoozes: snoozes, notes: {"packages" => {}}).errors
  end
end
