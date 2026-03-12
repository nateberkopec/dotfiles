require "test_helper"

class PatchPiAutoRetryStepTest < StepTestCase
  step_class Dotfiles::Step::PatchPiAutoRetryStep

  def test_should_run_when_pi_retry_matcher_is_unpatched
    @fake_system.stub_command("command -v pi 2>/dev/null", pi_binary_path, exit_status: 0)
    @fake_system.stub_file_content(pi_retry_file_path, unpatched_retry_file)

    assert_should_run
  end

  def test_complete_when_pi_retry_matcher_is_patched
    @fake_system.stub_command("command -v pi 2>/dev/null", pi_binary_path, exit_status: 0)
    @fake_system.stub_file_content(pi_retry_file_path, patched_retry_file)

    assert_complete
  end

  def test_complete_when_pi_is_not_installed
    @fake_system.stub_command("command -v pi 2>/dev/null", "", exit_status: 1)

    assert_complete
    refute_should_run
  end

  def test_run_patches_pi_retry_matcher
    @fake_system.stub_command("command -v pi 2>/dev/null", pi_binary_path, exit_status: 0)
    @fake_system.stub_file_content(pi_retry_file_path, unpatched_retry_file)

    step.run

    assert_command_run(:write_file, pi_retry_file_path, patched_retry_file)
  end

  private

  def pi_binary_path
    "/tmp/mise/installs/npm-mariozechner-pi-coding-agent/0.57.1/bin/pi"
  end

  def pi_retry_file_path
    "/tmp/mise/installs/npm-mariozechner-pi-coding-agent/0.57.1/lib/node_modules/@mariozechner/pi-coding-agent/dist/core/agent-session.js"
  end

  def unpatched_retry_file
    "return /overloaded|rate.?limit|too many requests|429|500|502|503|504|service.?unavailable|server error|internal error|connection.?error/i.test(err);"
  end

  def patched_retry_file
    "return /overloaded|rate.?limit|too many requests|429|500|502|503|504|service.?unavailable|server(?: |_)?error|internal(?: |_)?error|connection.?error/i.test(err);"
  end
end
