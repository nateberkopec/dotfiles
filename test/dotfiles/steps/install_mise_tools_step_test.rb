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
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 0)
    @fake_system.stub_command("mise ls --global --json", "{}", exit_status: 0)
    write_config("config", "mise_tools" => ["node@lts", "npm:@openai/codex"])

    assert_should_run
  end

  def test_complete_when_tools_installed
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 0)
    @fake_system.stub_command(
      "mise ls --global --json",
      {
        "node" => [{"requested_version" => "lts"}],
        "npm:@openai/codex" => [{"requested_version" => "latest"}]
      }.to_json,
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
    @fake_system.stub_debian
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 0)
    @fake_system.stub_command("mise ls --global --json", "{}", exit_status: 0)
    write_config(
      "config",
      "mise_tools" => [
        {"tool" => "github:pkgforge-dev/ghostty-appimage[bin=ghostty]", "platforms" => ["linux"]}
      ]
    )

    assert_should_run
  end

  def test_skips_platform_specific_tool_on_macos
    @fake_system.stub_macos
    write_config(
      "config",
      "mise_tools" => [
        {"tool" => "github:pkgforge-dev/ghostty-appimage[bin=ghostty]", "platforms" => ["linux"]}
      ]
    )

    refute_should_run
    assert_complete
  end
end
