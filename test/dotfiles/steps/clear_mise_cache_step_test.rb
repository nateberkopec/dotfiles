require "test_helper"

class ClearMiseCacheStepTest < StepTestCase
  step_class Dotfiles::Step::ClearMiseCacheStep

  def test_should_run_when_mise_install_would_install_tools
    stub_managed_global_mise_config
    stub_mise_available
    stub_install_check("mise node@20.0.0                ⇢ would install\n")

    assert_should_run
  end

  def test_should_not_run_when_mise_tools_are_installed
    stub_managed_global_mise_config
    stub_mise_available
    stub_install_check("mise all tools are installed\n")

    refute_should_run
  end

  def test_should_not_run_when_mise_is_missing
    stub_mise_missing

    refute_should_run
  end

  def test_should_not_run_when_offline
    with_env("MISE_OFFLINE" => "1") do
      stub_managed_global_mise_config
      stub_mise_available
      stub_install_check("mise node@20.0.0                ⇢ would install\n")

      refute_should_run
    end
  end

  def test_run_clears_mise_cache
    @fake_system.stub_command("mise cache clear --yes", "")

    step.run

    assert_executed("mise cache clear --yes")
  end

  private

  def stub_managed_global_mise_config
    @fake_system.stub_file_content(File.join(@home, ".config", "mise", "config.toml"), "[tools]\nnode = \"lts\"\n")
  end

  def stub_mise_available
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 0)
  end

  def stub_mise_missing
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 1)
  end

  def stub_install_check(output)
    @fake_system.stub_command("mise --cd #{@home} install --yes --dry-run", output, exit_status: 0)
  end
end
