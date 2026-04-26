require "test_helper"

class InstallApplicationsStepTest < StepTestCase
  step_class Dotfiles::Step::InstallApplicationsStep

  def test_depends_on_homebrew_update
    assert_equal [Dotfiles::Step::UpdateHomebrewStep], self.class.step_class.depends_on
  end

  def setup
    super
    @config = step.config
    @config.applications = apps
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

  def test_complete_when_non_admin_app_is_installed_in_user_applications
    app = apps.last
    @fake_system.filesystem[apps.first["path"]] = :directory
    @fake_system.filesystem[user_app_path(app)] = :directory

    assert_complete
  end

  def test_run_skips_install_when_non_admin_app_exists_in_user_applications
    app = apps.last
    @fake_system.filesystem[apps.first["path"]] = :directory
    @fake_system.filesystem[user_app_path(app)] = :directory

    step.run

    refute_executed(install_command_for(app))
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

  def user_app_path(app)
    File.join(@home, "Applications", File.basename(app["path"]))
  end
end
