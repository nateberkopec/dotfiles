require "test_helper"

class InstallBrewCasksStepTest < StepTestCase
  step_class Dotfiles::Step::InstallBrewCasksStep

  def test_has_no_step_dependencies
    assert_empty self.class.step_class.depends_on
  end

  def test_run_updates_homebrew_and_installs_casks_for_admin_user
    stub_admin
    write_config(:brew, "brew_casks" => ["ghostty"])
    @fake_system.stub_command(update_command, "")
    @fake_system.stub_command(bundle_install_command(admin: true), "", exit_status: 0)
    @fake_system.stub_command(bundle_check_command, "", exit_status: 0)

    step.run

    assert_executed(update_command)
    assert_executed(bundle_install_command(admin: true))
  end

  def test_run_installs_formulae_for_non_admin_user
    stub_non_admin
    write_config(:brew, "brew_casks" => ["ghostty"])
    @fake_system.stub_command(mise_status_command, mise_status_json)
    @fake_system.stub_command(update_command, "")
    @fake_system.stub_command(bundle_install_command, "", exit_status: 0)
    @fake_system.stub_command(bundle_check_command, "", exit_status: 0)

    step.run

    assert_executed(bundle_install_command)
  end

  def test_brewfile_omits_formulae_for_admin_user
    stub_admin
    write_config(:brew, "brew_casks" => ["ghostty"])

    content = step.send(:brewfile_content)

    refute_includes content, 'brew "duti"'
    assert_includes content, 'cask "ghostty"'
  end

  def test_brewfile_includes_formulae_for_non_admin_user
    stub_non_admin
    write_config(:brew, "brew_casks" => [])
    @fake_system.stub_command(mise_status_command, mise_status_json)

    assert_equal %(brew "duti"\n), step.send(:brewfile_content)
  end

  def test_brewfile_omits_formulae_when_mise_status_is_unusable
    stub_non_admin
    write_config(:brew, "brew_casks" => [])

    [["bad", 0], ["{}", 1]].each do |output, status|
      @fake_system.stub_command(mise_status_command, output, exit_status: status)
      step.instance_variable_set(:@formulae, nil)
      assert_equal "\n", step.send(:brewfile_content)
    end
  end

  def test_complete_checks_homebrew_state_when_packages_are_needed
    stub_admin
    write_config(:brew, "brew_casks" => ["ghostty"])
    @fake_system.stub_command(bundle_check_command, "Unsatisfied dependency: ghostty", exit_status: 1)
    step.instance_variable_set(:@ran, true)

    assert_incomplete
    assert_includes step.errors.join("\n"), "ghostty"
  end

  def test_complete_skips_homebrew_when_no_packages_are_needed
    stub_admin
    write_config(:brew, "brew_casks" => [])

    assert_complete
    refute_executed(bundle_check_command)
  end

  private

  def stub_admin
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "admin staff")
  end

  def stub_non_admin
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "staff")
  end

  def brewfile_path
    step.instance_variable_get(:@brewfile_path)
  end

  def mise_status_command
    "mise -C #{@home} bootstrap packages status --json 2>&1"
  end

  def mise_status_json
    '{"brew":{"packages":[{"package":"duti"}]}}'
  end

  def update_command
    "HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew update 2>&1"
  end

  def bundle_check_command
    "HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew bundle check --file=#{brewfile_path} --no-upgrade 2>&1"
  end

  def bundle_install_command(admin: false)
    cask_opts = admin ? "" : "--appdir=~/Applications"
    %(HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_CASK_OPTS="#{cask_opts}" brew bundle install --file=#{brewfile_path} 2>&1)
  end
end
