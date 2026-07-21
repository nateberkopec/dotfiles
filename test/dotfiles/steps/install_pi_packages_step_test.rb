require "test_helper"

class InstallPiPackagesStepTest < StepTestCase
  step_class Dotfiles::Step::InstallPiPackagesStep

  def test_depends_on_mise_tools_and_home_directory_sync
    assert_equal [
      Dotfiles::Step::InstallMiseToolsStep,
      Dotfiles::Step::SyncHomeDirectoryStep
    ], self.class.step_class.depends_on
  end

  def test_should_not_run_by_default
    refute_should_run
  end

  def test_should_run_when_pinned_package_is_missing
    stub_settings('{"packages":["npm:pi-ding@0.2.2"]}')
    stub_pi_available
    stub_pi_list("")

    assert_should_run
  end

  def test_should_not_run_when_pinned_package_is_installed
    stub_settings('{"packages":["npm:pi-ding@0.2.2"]}')
    stub_pi_available
    stub_installed_npm_package("pi-ding", "0.2.2")

    refute_should_run
  end

  def test_should_run_when_installed_npm_package_does_not_match_pin
    stub_settings('{"packages":["npm:pi-subagents@0.34.0"]}')
    stub_pi_available
    stub_pi_list("User packages:\n  npm:pi-subagents@0.34.0\n")
    stub_installed_npm_package("pi-subagents", "0.25.0")

    assert_should_run
  end

  def test_run_installs_missing_pinned_package
    stub_settings('{"packages":["npm:pi-ding@0.2.2"]}')
    stub_pi_available
    stub_pi_list("")
    @fake_system.stub_command("pi install npm:pi-ding@0.2.2", "")

    step.run

    assert_executed("pi install npm:pi-ding@0.2.2")
  end

  def test_complete_reports_missing_pi
    stub_settings('{"packages":["npm:pi-ding@0.2.2"]}')
    @fake_system.stub_command("command -v pi >/dev/null 2>&1", "", exit_status: 1)

    assert_incomplete
  end

  private

  def stub_settings(content)
    @fake_system.stub_file_content(File.join(@home, ".pi", "agent", "settings.json"), content)
  end

  def stub_pi_available
    @fake_system.stub_command("command -v pi >/dev/null 2>&1", "", exit_status: 0)
  end

  def stub_pi_list(output)
    @fake_system.stub_command("pi list", output)
  end

  def stub_installed_npm_package(name, version)
    path = File.join(@home, ".pi", "agent", "npm", "node_modules", name, "package.json")
    @fake_system.stub_file_content(path, JSON.generate("version" => version))
  end
end
