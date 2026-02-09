require "test_helper"

class InstallMiseToolsStepTest < StepTestCase
  step_class Dotfiles::Step::InstallMiseToolsStep

  def test_should_not_run_by_default
    refute_should_run
  end

  def test_complete_by_default
    assert_complete
  end

  def test_should_run_when_configured_and_missing
    ENV.delete("MISE_OFFLINE")
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 0)
    @fake_system.stub_command(
      mise_install_command("node@lts", "npm:@openai/codex", dry_run: true),
      "mise node@20.0.0                ⇢ would install\n",
      exit_status: 0
    )
    write_config("config", "mise_tools" => ["node@lts", "npm:@openai/codex"])

    assert_should_run
  end

  def test_complete_when_tools_installed
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 0)
    @fake_system.stub_command(
      mise_install_command("node@lts", "npm:@openai/codex", dry_run: true),
      "mise node@20.0.0                ⇢ already installed\nmise npm:@openai/codex@latest     ⇢ already installed\n",
      exit_status: 0
    )
    write_config("config", "mise_tools" => ["node@lts", "npm:@openai/codex"])

    assert_complete
  end

  def test_incomplete_when_mise_missing
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 1)
    write_config("config", "mise_tools" => ["node@lts"])

    assert_incomplete
  end

  def test_should_run_with_platform_specific_tool
    ENV.delete("MISE_OFFLINE")
    @fake_system.stub_debian
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 0)
    @fake_system.stub_command(
      mise_install_command("github:example/example[bin=example]", dry_run: true),
      "mise github:example/example[bin=example] ⇢ would install\n",
      exit_status: 0
    )
    write_config(
      "config",
      "mise_tools" => [
        {"tool" => "github:example/example[bin=example]", "platforms" => ["linux"]}
      ]
    )

    assert_should_run
  end

  def test_skips_platform_specific_tool_on_macos
    @fake_system.stub_macos
    write_config(
      "config",
      "mise_tools" => [
        {"tool" => "github:example/example[bin=example]", "platforms" => ["linux"]}
      ]
    )

    refute_should_run
    assert_complete
  end

  def test_should_not_run_when_mise_offline
    with_env("MISE_OFFLINE" => "1") do
      @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 0)
      @fake_system.stub_command(
        mise_install_command("node@lts", dry_run: true),
        "mise node@20.0.0                ⇢ would install\n",
        exit_status: 0
      )
      write_config("config", "mise_tools" => ["node@lts"])

      refute_should_run
    end
  end

  def test_run_installs_configured_tools
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 0)
    @fake_system.stub_command(mise_install_command("node@lts"), "", exit_status: 0)
    write_config("config", "mise_tools" => ["node@lts"])

    step.run

    assert_executed(mise_install_command("node@lts"))
  end

  def test_mise_ci_tools_overrides_config
    with_env("MISE_CI_TOOLS" => "fzf@latest, zoxide@latest") do
      @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 0)
      @fake_system.stub_command(mise_install_command("fzf@latest", "zoxide@latest"), "", exit_status: 0)
      write_config("config", "mise_tools" => ["node@lts", "rust@latest"])

      step.run

      assert_executed(mise_install_command("fzf@latest", "zoxide@latest"))
    end
  end

  private

  def mise_install_command(*specs, dry_run: false)
    command = "mise --cd #{@home} install --yes"
    command = "#{command} --dry-run" if dry_run
    return command if specs.empty?

    "#{command} #{specs.join(" ")}"
  end
end
