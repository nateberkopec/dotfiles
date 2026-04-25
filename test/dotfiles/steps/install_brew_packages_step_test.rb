require "test_helper"

class InstallBrewPackagesStepTest < StepTestCase
  step_class Dotfiles::Step::InstallBrewPackagesStep

  def test_depends_on_homebrew
    deps = self.class.step_class.depends_on

    assert_includes deps, Dotfiles::Step::InstallHomebrewStep
    assert_includes deps, Dotfiles::Step::UpdateHomebrewStep
  end

  def test_run_installs_packages_for_non_admin_user
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "staff")
    @fake_system.stub_command(bundle_install_command, "", exit_status: 0)
    @fake_system.stub_command("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew list --formula 2>&1", "duti\nmise", exit_status: 0)
    @fake_system.stub_command("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew list --cask 2>&1", "", exit_status: 0)

    with_env("BREW_CI_PACKAGES" => "duti,mise", "BREW_CI_CASKS" => "") do
      step.run
    end

    assert_executed(bundle_install_command)
  end

  def test_run_uses_default_applications_dir_for_admin_user
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "admin staff")
    @fake_system.stub_command(bundle_install_command(admin: true), "", exit_status: 0)
    @fake_system.stub_command("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew list --formula 2>&1", "duti\nmise", exit_status: 0)
    @fake_system.stub_command("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew list --cask 2>&1", "", exit_status: 0)

    with_env("BREW_CI_PACKAGES" => "duti,mise", "BREW_CI_CASKS" => "") do
      step.run
    end

    assert_executed(bundle_install_command(admin: true))
  end

  private

  def bundle_install_command(admin: false)
    cask_opts = admin ? "" : "--appdir=~/Applications"
    %(HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_CASK_OPTS="#{cask_opts}" brew bundle install --file=#{@dotfiles_dir}/Brewfile 2>&1)
  end
end
