require "test_helper"

class InstallApplicationsStepTest < StepTestCase
  step_class Dotfiles::Step::InstallApplicationsStep

  def setup
    super
    @config = step.config
    @config.packages = {"applications" => apps}
  end

  def test_complete_when_all_apps_present
    apps.each { |app| @fake_system.filesystem[app["path"]] = :directory }
    assert_complete
  end

  def test_incomplete_when_app_missing
    apps.drop(1).each { |app| @fake_system.filesystem[app["path"]] = :directory }
    assert_incomplete
  end

  def test_run_installs_missing_apps_and_skips_existing
    existing_app = apps.first
    missing_app = apps.last
    @fake_system.filesystem[existing_app["path"]] = :directory

    step.run

    assert_executed(install_command_for(missing_app))
    refute_executed(install_command_for(existing_app))
  end

  private

  def apps
    @apps ||= [
      {"name" => "Ghostty", "path" => File.join(@home, "Applications/Ghostty.app"), "brew_cask" => "ghostty"},
      {"name" => "1Password", "path" => "/Applications/1Password.app", "brew_cask" => "1password"}
    ]
  end

  def install_command_for(app)
    flag = "--appdir=~/Applications"
    "HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew install --cask #{flag} #{app["brew_cask"]} 2>&1"
  end
end
