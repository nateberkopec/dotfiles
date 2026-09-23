require "test_helper"
require "open3"

class LockWorkflowResultTest < Minitest::Test
  SCRIPT = File.expand_path("../../tools/ci/check_lock_workflow_result.sh", __dir__)

  def test_accepts_unchanged_inputs_when_platform_jobs_are_skipped
    assert_result true, "success", "false", "skipped", "skipped"
  end

  def test_accepts_changed_inputs_when_both_platform_jobs_succeed
    assert_result true, "success", "true", "success", "success"
  end

  def test_rejects_every_non_successful_detection_result
    %w[failure cancelled skipped].each do |result|
      assert_result false, result, "false", "skipped", "skipped"
    end
  end

  def test_rejects_missing_or_unknown_change_detection_output
    ["", "unknown"].each do |lock_changed|
      assert_result false, "success", lock_changed, "success", "success"
    end
  end

  def test_rejects_changed_inputs_unless_every_platform_succeeds
    [%w[failure success], %w[success failure], %w[cancelled success], %w[success cancelled], %w[skipped success], %w[success skipped]].each do |linux_result, macos_result|
      assert_result false, "success", "true", linux_result, macos_result
    end
  end

  def test_rejects_platform_execution_for_unchanged_inputs
    [%w[success skipped], %w[skipped success], %w[failure skipped], %w[skipped cancelled]].each do |linux_result, macos_result|
      assert_result false, "success", "false", linux_result, macos_result
    end
  end

  private

  def assert_result(expected, *results)
    output, status = Open3.capture2e("bash", SCRIPT, *results)

    assert_equal expected, status.success?, "#{results.join(", ")} produced:\n#{output}"
  end
end
