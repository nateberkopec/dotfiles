require_relative "e2e_helper"

class ConvergeTest < Minitest::Test
  def test_first_run_fails_only_allowed_steps
    log = E2E.run_log("first-run")
    failed = incomplete_steps(log)
    assert log.include?("All Steps Complete") || failed.any?, "dotf run reported neither success nor failed steps"
    assert_empty failed - E2E::ALLOWED_FAILURES
  end

  def test_second_run_runs_no_steps
    ran = E2E.run_log("second-run").scan(/Running step: (.+?)\s*$/).flatten
    assert_empty ran - E2E::ALLOWED_FAILURES
  end

  private

  def incomplete_steps(log)
    section = log[/Incomplete steps:(.*)/m, 1].to_s
    section.scan(/•\s+(.+?)\s*[┃│]?\s*$/).flatten
  end
end
