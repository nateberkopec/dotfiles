require "test_helper"
require "yaml"
require "open3"

# standard:disable Dotfiles/BanFileSystemClasses
class DependencyWorkflowTest < Minitest::Test
  def test_publisher_requires_completed_validation_before_the_handler
    steps = workflow.fetch("jobs").fetch("safe_outputs").fetch("steps")
    guard = steps.index { |step| step["name"] == "Require completed validation" }
    handler = steps.index { |step| step["name"] == "Process Safe Outputs" }
    assert_equal guard + 1, handler
    assert_equal "always()", steps[guard]["if"]
    refute steps[handler].key?("if"), "Handler must retain implicit success(), not always()"
    refute steps[guard]["continue-on-error"]
    assert_includes workflow.fetch("jobs").fetch("safe_outputs").fetch("if"), "needs.agent.result == 'success'"
  end

  def test_conclusion_keeps_accounting_without_a_validation_dependency
    conclusion = workflow.fetch("jobs").fetch("conclusion")
    refute_includes conclusion.fetch("if"), "dependency_validation"
    steps = conclusion.fetch("steps")
    assert steps.any? { |step| step.dig("with", "name") == "usage" }
    assert steps.any? { |step| step.dig("with", "script").to_s.include?("write_daily_aic_usage_cache") }
  end

  def test_successful_ci_has_no_model_entry
    source = File.read(File.expand_path("../../.github/workflows/dependency-updater.md", __dir__))
    assert_includes source, "github.event.workflow_run.conclusion == 'failure'"
  end

  def test_duplicate_failure_stops_before_the_model
    steps = workflow.fetch("jobs").fetch("agent").fetch("steps")
    claim = steps.index { |step| step["name"] == "Claim this failure before model entry" }
    model = steps.index { |step| step["name"] == "Execute Codex CLI" }
    assert_operator claim, :<, model
    output, status = Open3.capture2e({"SEEN" => "true"}, "bash", "-e", "-c", steps[claim].fetch("run"))
    refute status.success?
    assert_includes output, "Failure already handled"
    cache = steps.find { |step| step["id"] == "repair_seen" }
    assert_includes cache.dig("with", "key"), "head_sha"
    assert_includes cache.dig("with", "key"), "workflow_id"
    assert steps.any? { |step| step["name"] == "Require the claim to be stored" }
  end

  def test_native_success_and_current_attempt_receipts_gate_publication
    jobs = workflow.fetch("jobs")
    assert_equal %w[agent detection], jobs.fetch("native").fetch("needs")
    assert_equal({"actions" => "read", "contents" => "read", "pull-requests" => "read"}, jobs.fetch("native").fetch("permissions"))
    assert_equal "./.github/workflows/lock-provenance.yml", jobs.fetch("native").fetch("uses")
    publisher = jobs.fetch("safe_outputs")
    assert_includes publisher.fetch("needs"), "native"
    assert_includes publisher.fetch("if"), "needs.native.result == 'success'"
    download = publisher.fetch("steps").find { |step| step.dig("with", "path") == "/tmp/native-receipts" }
    assert_equal "native-${{ github.run_attempt }}-*", download.dig("with", "pattern")
    refute download.fetch("with").key?("run-id")
    native = YAML.load_file(File.expand_path("../../.github/workflows/lock-provenance.yml", __dir__))
    assert_equal "read", native.dig("permissions", "contents")
    steps = native.dig("jobs", "native", "steps")
    refute steps.first.dig("with", "persist-credentials")
    assert_equal "${{ inputs.factory && github.sha || github.event.pull_request.head.sha || github.sha }}", steps.first.dig("with", "ref")
    receipt = steps.find { |step| step.dig("with", "name").to_s.start_with?("native-${{") }
    assert_equal "success()", receipt.fetch("if")
  end

  private

  def workflow
    YAML.load_file(File.expand_path("../../.github/workflows/dependency-updater.lock.yml", __dir__))
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
