require "test_helper"
require "open3"

# standard:disable Dotfiles/BanFileSystemClasses
class IntegrationWorkflowTest < Minitest::Test
  RESULT_CHECKER = File.expand_path("../tools/ci/check_integration_results.sh", __dir__)
  WORKFLOW = File.expand_path("../.github/workflows/full-integration-test.yml", __dir__)

  def test_optional_change_accepts_skipped_integration_jobs
    assert_result "success", "true", "skipped", "skipped"
  end

  def test_required_change_accepts_successful_integration_jobs
    assert_result "success", "false", "success", "success"
  end

  def test_failed_detection_fails_aggregate
    refute_result "failure", "", "skipped", "skipped"
  end

  def test_unknown_detection_output_fails_aggregate
    refute_result "success", "", "skipped", "skipped"
  end

  def test_failed_or_skipped_required_job_fails_aggregate
    refute_result "success", "false", "failure", "success"
    refute_result "success", "false", "success", "skipped"
  end

  def test_unexpected_optional_job_execution_fails_aggregate
    refute_result "success", "true", "success", "skipped"
  end

  def test_workflow_keeps_all_full_coverage_events
    workflow = File.read(WORKFLOW)

    assert_match(/^  push:\n    branches: \[ main \]$/, workflow)
    assert_match(/^  pull_request:\n    branches: \[ main \]$/, workflow)
    assert_includes workflow, "  schedule:\n    - cron: \"23 6 * * *\""
    assert_match(/^  workflow_dispatch:$/, workflow)
  end

  def test_only_aggregate_runs_for_optional_changes
    workflow = File.read(WORKFLOW)
    required_change_condition = "needs.detect-changes.result == 'success' && needs.detect-changes.outputs.integration_optional == 'false'"

    assert_equal 2, workflow.scan(required_change_condition).length
    assert_includes workflow, "integration-result:\n    needs: [detect-changes, integration-test, non-admin-integration-test]"
    assert_includes workflow, "if: ${{ always() && !cancelled() }}"
    refute_includes workflow, "ubuntu-slim' || matrix.os"
  end

  private

  def assert_result(*arguments)
    output, status = Open3.capture2e("/bin/bash", RESULT_CHECKER, *arguments)
    assert status.success?, output
  end

  def refute_result(*arguments)
    _output, status = Open3.capture2e("/bin/bash", RESULT_CHECKER, *arguments)
    refute status.success?
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
