require "test_helper"

class InstallBrewPackagesStepTest < StepTestCase
  step_class Dotfiles::Step::InstallBrewPackagesStep

  def test_depends_on_homebrew
    deps = self.class.step_class.depends_on

    assert_includes deps, Dotfiles::Step::InstallHomebrewStep
    assert_includes deps, Dotfiles::Step::UpdateHomebrewStep
  end

  def test_run_preinstalls_fish_for_non_admin_when_missing
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "staff")
    @fake_system.stub_command("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew list --formula fish 2>&1", "", exit_status: 1)
    @fake_system.stub_command("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew install fish 2>&1", "", exit_status: 0)
    @fake_system.stub_command(bundle_install_command, "", exit_status: 0)
    @fake_system.stub_command("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew list --formula 2>&1", "fish\nduti\nmise", exit_status: 0)
    @fake_system.stub_command("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew list --cask 2>&1", "", exit_status: 0)

    write_config(:brew, {"brew" => {"packages" => ["fish", "duti", "mise"], "casks" => []}})

    step.run

    assert_executed("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew install fish 2>&1")
    assert_executed(bundle_install_command)
  end

  def test_run_skips_fish_preinstall_for_admin_user
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "admin staff")
    @fake_system.stub_command(bundle_install_command(admin: true), "", exit_status: 0)
    @fake_system.stub_command("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew list --formula 2>&1", "fish\nduti\nmise", exit_status: 0)
    @fake_system.stub_command("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew list --cask 2>&1", "", exit_status: 0)

    write_config(:brew, {"brew" => {"packages" => ["fish", "duti", "mise"], "casks" => []}})

    step.run

    refute_executed("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew install fish 2>&1")
    assert_executed(bundle_install_command(admin: true))
  end

  def test_install_formula_with_retries_retries_lock_errors
    responses = [["Error: A `brew install --formula fish` process has already locked something", 1], ["", 0]]
    install_attempts = 0
    sleeps = []
    step_instance = step

    step_instance.define_singleton_method(:brew_install_formula) do |_name|
      install_attempts += 1
      responses.shift
    end
    step_instance.define_singleton_method(:brew_formula_installed?) { |_name| false }
    step_instance.define_singleton_method(:sleep) { |seconds| sleeps << seconds }

    _output, status = step_instance.send(:install_formula_with_retries, "fish")

    assert_equal 0, status
    assert_equal 2, install_attempts
    assert_equal [3], sleeps
  end

  def test_install_formula_with_retries_treats_installed_formula_as_success
    step_instance = step
    step_instance.define_singleton_method(:brew_install_formula) { |_name| ["post-install failed", 1] }
    step_instance.define_singleton_method(:brew_formula_installed?) { |_name| true }

    _output, status = step_instance.send(:install_formula_with_retries, "fish")

    assert_equal 0, status
  end

  private

  def bundle_install_command(admin: false)
    cask_opts = admin ? "" : "--appdir=~/Applications"
    %(HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_CASK_OPTS="#{cask_opts}" brew bundle install --file=#{@dotfiles_dir}/Brewfile 2>&1)
  end
end
