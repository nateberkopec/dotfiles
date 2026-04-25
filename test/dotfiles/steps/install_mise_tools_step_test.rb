require "test_helper"

class InstallMiseToolsStepTest < StepTestCase
  step_class Dotfiles::Step::InstallMiseToolsStep

  def test_should_not_run_by_default
    refute_should_run
  end

  def test_complete_by_default
    assert_complete
  end

  def test_should_run_when_global_config_has_missing_tools
    stub_managed_global_mise_config
    stub_mise_available
    stub_install_check("mise node@20.0.0                ⇢ would install\n")

    assert_should_run
  end

  def test_complete_when_global_config_tools_are_installed
    stub_managed_global_mise_config
    stub_mise_available
    stub_install_check("mise all tools are installed\n")

    assert_complete
  end

  def test_incomplete_when_mise_missing
    stub_managed_global_mise_config
    stub_mise_missing

    assert_incomplete
  end

  def test_should_not_run_when_mise_offline
    with_env("MISE_OFFLINE" => "1") do
      stub_managed_global_mise_config
      stub_mise_available
      stub_install_check("mise node@20.0.0                ⇢ would install\n")

      refute_should_run
    end
  end

  def test_run_installs_tools_from_global_config
    stub_managed_global_mise_config
    stub_mise_available
    @fake_system.stub_command(mise_install_command, "", exit_status: 0)

    step.run

    assert_executed(mise_install_command)
  end

  def test_mise_ci_tools_overrides_global_config
    with_env("MISE_CI_TOOLS" => "fzf@latest, zoxide@latest") do
      stub_managed_global_mise_config
      stub_mise_available
      @fake_system.stub_command(mise_install_command("fzf@latest", "zoxide@latest"), "", exit_status: 0)

      step.run

      assert_executed(mise_install_command("fzf@latest", "zoxide@latest"))
    end
  end

  private

  def global_mise_config_path
    File.join(@home, ".config", "mise", "config.toml")
  end

  def stub_managed_global_mise_config
    @fake_system.stub_file_content(global_mise_config_path, "[tools]\nnode = \"lts\"\n")
  end

  def stub_mise_available
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 0)
  end

  def stub_mise_missing
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 1)
  end

  def stub_install_check(output)
    @fake_system.stub_command(mise_install_command(dry_run: true), output, exit_status: 0)
  end

  def mise_install_command(*specs, dry_run: false)
    command = "mise --cd #{@home} install --yes"
    command = "#{command} --dry-run" if dry_run
    return command if specs.empty?

    "#{command} #{specs.join(" ")}"
  end
end
