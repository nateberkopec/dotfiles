require "test_helper"

class InstallBrewPackagesStepTest < StepTestCase
  step_class Dotfiles::Step::InstallBrewPackagesStep

  def test_depends_on_homebrew_update
    assert_equal [Dotfiles::Step::UpdateHomebrewStep], self.class.step_class.depends_on
  end

  def test_run_installs_brew_bundle_for_non_admin_user
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "staff")
    @fake_system.stub_command(bundle_install_command, "", exit_status: 0)
    @fake_system.stub_command("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew list --formula 2>&1", "duti\nmise", exit_status: 0)
    @fake_system.stub_command("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew list --cask 2>&1", "", exit_status: 0)

    write_config(:brew, {"brew" => {"packages" => ["duti", "mise"], "casks" => []}})

    step.run

    assert_executed(bundle_install_command)
  end

  def test_run_installs_brew_bundle_for_admin_user
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "admin staff")
    @fake_system.stub_command(bundle_install_command(admin: true), "", exit_status: 0)
    @fake_system.stub_command("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew list --formula 2>&1", "duti\nmise", exit_status: 0)
    @fake_system.stub_command("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew list --cask 2>&1", "", exit_status: 0)

    write_config(:brew, {"brew" => {"packages" => ["duti", "mise"], "casks" => []}})

    step.run

    assert_executed(bundle_install_command(admin: true))
  end

  def test_build_brewfile_content_omits_fish_when_config_has_no_brew_fish_package
    content = step.send(:build_brewfile_content, {"packages" => ["duti", "mise"], "casks" => []})

    refute_includes content, 'brew "fish"'
    assert_includes content, 'brew "duti"'
    assert_includes content, 'brew "mise"'
  end

  private

  def bundle_install_command(admin: false)
    cask_opts = admin ? "" : "--appdir=~/Applications"
    %(HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_CASK_OPTS="#{cask_opts}" brew bundle install --file=#{@dotfiles_dir}/Brewfile 2>&1)
  end
end
