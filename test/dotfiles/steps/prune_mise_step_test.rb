require "test_helper"

class PruneMiseStepTest < StepTestCase
  step_class Dotfiles::Step::PruneMiseStep

  def test_should_run_when_mise_tools_are_prunable
    stub_mise_available
    stub_prunable_tools

    assert_should_run
  end

  def test_should_run_when_mise_cache_is_prunable
    stub_mise_available
    stub_no_prunable_tools
    stub_prunable_cache

    assert_should_run
  end

  def test_should_not_run_when_nothing_is_prunable
    stub_mise_available
    stub_no_prunable_tools
    stub_no_prunable_cache

    refute_should_run
  end

  def test_should_not_run_when_mise_is_missing
    stub_mise_missing

    refute_should_run
  end

  def test_should_not_run_with_ci_tools
    with_env("MISE_CI_TOOLS" => "fzf@latest") do
      stub_mise_available

      refute_should_run
    end
  end

  def test_should_not_run_when_offline
    with_env("MISE_OFFLINE" => "1") do
      stub_mise_available

      refute_should_run
    end
  end

  def test_run_prunes_mise_installs_and_cache
    @fake_system.stub_command("mise prune --yes", "")
    @fake_system.stub_command("mise cache prune --yes", "")

    step.run

    assert_executed("mise prune --yes")
    assert_executed("mise cache prune --yes")
  end

  private

  def stub_mise_available
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 0)
  end

  def stub_mise_missing
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 1)
  end

  def stub_prunable_tools
    @fake_system.stub_command("mise prune --dry-run-code --yes", "rm old-tool", exit_status: 1)
  end

  def stub_no_prunable_tools
    @fake_system.stub_command("mise prune --dry-run-code --yes", "", exit_status: 0)
  end

  def stub_prunable_cache
    @fake_system.stub_command("mise cache prune --dry-run --verbose", "rm cache-file")
  end

  def stub_no_prunable_cache
    @fake_system.stub_command("mise cache prune --dry-run --verbose", "")
  end
end
