require "test_helper"

class InstallBrewPackagesStepTest < StepTestCase
  step_class Dotfiles::Step::InstallBrewPackagesStep

  def test_depends_on_homebrew_update
    assert_equal [Dotfiles::Step::UpdateHomebrewStep], self.class.step_class.depends_on
  end

  def test_run_installs_casks_for_admin_user
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "admin staff")
    @fake_system.stub_command(bundle_install_command(admin: true), "", exit_status: 0)

    write_config(:brew, {"brew" => {"packages" => ["duti"], "casks" => ["ghostty"]}})

    step.run

    assert_executed(bundle_install_command(admin: true))
  end

  def test_run_installs_formulae_for_non_admin_user
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "staff")
    @fake_system.stub_command(bundle_install_command, "", exit_status: 0)

    write_config(:brew, {"brew" => {"packages" => ["duti"], "casks" => ["ghostty"]}})

    step.run

    assert_executed(bundle_install_command)
  end

  def test_build_brewfile_content_omits_formulae_for_admin_user
    @fake_system.stub_command("groups", "admin staff")
    content = step.send(:build_brewfile_content, {"packages" => ["duti"], "casks" => ["ghostty"]})

    refute_includes content, 'brew "duti"'
    assert_includes content, 'cask "ghostty"'
  end

  def test_build_brewfile_content_includes_formulae_for_non_admin_user
    @fake_system.stub_command("groups", "staff")
    content = step.send(:build_brewfile_content, {"packages" => ["duti"], "casks" => []})

    assert_equal %(brew "duti"\n), content
  end

  def test_build_brewfile_content_includes_taps_before_casks
    content = step.send(:build_brewfile_content, {"taps" => ["example/tap"], "packages" => [], "casks" => ["ghostty"]})

    assert_equal %(tap "example/tap"\ncask "ghostty"\n), content
  end

  def test_complete_checks_homebrew_state_when_brewfile_needed
    @fake_system.stub_command("groups", "admin staff")
    write_config(:brew, {"brew" => {"packages" => [], "casks" => ["ghostty"]}})
    @fake_system.stub_command(bundle_check_command, %(Brewfile's dependencies are not satisfied.\nUnsatisfied dependency: ghostty), exit_status: 1)
    step.instance_variable_set(:@ran, true)

    assert_incomplete
    assert_includes step.errors.join("\n"), "ghostty"
    assert_executed(bundle_check_command)
  end

  def test_complete_skips_homebrew_when_no_brewfile_entries_are_needed
    @fake_system.stub_command("groups", "admin staff")
    write_config(:brew, {"brew" => {"packages" => ["duti"], "casks" => []}})

    assert_complete
    refute_executed(bundle_check_command)
  end

  def test_run_clears_cached_failed_package_check_before_completion
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "admin staff")
    @fake_system.stub_command(bundle_check_command, "Brewfile's dependencies are not satisfied", exit_status: 1)
    write_config(:brew, {"brew" => {"packages" => [], "casks" => ["ghostty"]}})

    assert_should_run

    @fake_system.stub_command(bundle_install_command(admin: true), "", exit_status: 0)
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
