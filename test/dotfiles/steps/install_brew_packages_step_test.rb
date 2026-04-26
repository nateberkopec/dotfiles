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

  def test_complete_checks_homebrew_state_even_after_step_ran
    @fake_system.stub_file_content(brewfile_path, %(brew "mise"\n))
    @fake_system.stub_command(bundle_check_command, %(Brewfile's dependencies are not satisfied.\nUnsatisfied dependency: mise), exit_status: 1)
    step.instance_variable_set(:@ran, true)

    assert_incomplete
    assert_includes step.errors.join("\n"), "mise"
    assert_executed(bundle_check_command)
  end

  def test_run_clears_cached_failed_package_check_before_completion
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "staff")
    @fake_system.stub_command(bundle_check_command, "Brewfile's dependencies are not satisfied", exit_status: 1)
    write_config(:brew, {"brew" => {"packages" => ["duti", "mise"], "casks" => []}})

    assert_should_run

    @fake_system.stub_command(bundle_install_command, "", exit_status: 0)
    @fake_system.stub_command("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew list --formula 2>&1", "duti\nmise", exit_status: 0)
    @fake_system.stub_command("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew list --cask 2>&1", "", exit_status: 0)
    @fake_system.stub_command(bundle_check_command, "The Brewfile's dependencies are satisfied.", exit_status: 0)

    step.run

    assert_complete
  end

  private

  def brewfile_path
    File.join(@dotfiles_dir, "Brewfile")
  end

  def bundle_check_command
    "HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew bundle check --file=#{brewfile_path} --no-upgrade 2>&1"
  end

  def bundle_install_command(admin: false)
    cask_opts = admin ? "" : "--appdir=~/Applications"
    %(HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_CASK_OPTS="#{cask_opts}" brew bundle install --file=#{@dotfiles_dir}/Brewfile 2>&1)
  end
end
