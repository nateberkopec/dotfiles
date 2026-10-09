require "test_helper"

class InstallBrewCasksStepTest < StepTestCase
  step_class Dotfiles::Step::InstallBrewCasksStep

  def test_has_no_step_dependencies
    assert_empty self.class.step_class.depends_on
  end

  def test_installs_only_missing_casks_for_admin_user
    stub_admin
    write_config(:brew, "brew_casks" => ["ghostty", "firefox"])
    @fake_system.stub_command(list_command("cask", "ghostty"), "ghostty 1.0")
    @fake_system.stub_command(list_command("cask", "firefox"), "", exit_status: 1)
    @fake_system.stub_command(update_command, "")
    @fake_system.stub_command(install_command("cask", "firefox"), "")

    step.run

    assert_executed!(update_command)
    assert_cask_installed(install_command("cask", "firefox"))
    refute_executed(install_command("cask", "ghostty"))
  end

  def test_qualified_cask_is_checked_by_token_but_installed_by_full_name
    stub_admin
    write_config(:brew, "brew_casks" => ["homebrew/cask/ghostty"])
    @fake_system.stub_command(list_command("cask", "ghostty"), "", exit_status: 1)

    assert_should_run
    step.run

    assert_executed(list_command("cask", "ghostty"))
    assert_cask_installed(install_command("cask", "homebrew/cask/ghostty"))
  end

  def test_failed_homebrew_refresh_prevents_installation
    stub_admin
    write_config(:brew, "brew_casks" => ["ghostty"])
    @fake_system.stub_command(update_command, "network failure", exit_status: 1)
    @fake_system.stub_command(list_command("cask", "ghostty"), "", exit_status: 1)

    assert_raises(RuntimeError) { step.run }
    refute_executed(install_command("cask", "ghostty"))
  end

  def test_non_admin_installs_formulae_and_casks_with_private_appdir
    stub_non_admin
    write_config(:brew, "brew_casks" => ["ghostty"])
    @fake_system.stub_command(mise_status_command, mise_status_json)
    @fake_system.stub_command(list_command("formula", "duti"), "", exit_status: 1)
    @fake_system.stub_command(list_command("cask", "ghostty"), "", exit_status: 1)

    assert_should_run
    assert_incomplete
    step.run

    assert_executed(install_command("formula", "duti"))
    assert_cask_installed(install_command("cask", "ghostty", private_appdir: true))
  end

  def test_non_admin_packages_remain_eligible_in_ci
    stub_non_admin
    with_env("CI" => "true", "NONINTERACTIVE" => nil, "BREW_CI_CASKS" => "ghostty") do
      @fake_system.stub_command(mise_status_command, mise_status_json)
      @fake_system.stub_command(list_command("formula", "duti"), "", exit_status: 1)
      @fake_system.stub_command(list_command("cask", "ghostty"), "", exit_status: 1)

      assert_should_run
      assert_incomplete
      step.run

      assert_executed(install_command("formula", "duti"))
      assert_cask_installed(install_command("cask", "ghostty", private_appdir: true))
    end
  end

  def test_noninteractive_without_passwordless_sudo_skips_all_homebrew_operations
    stub_non_admin
    stub_sudo_requires_password
    write_config(:brew, "brew_casks" => ["ghostty"])
    %w[1 true].each do |mode|
      with_env("NONINTERACTIVE" => mode) do
        refute_should_run
        assert_complete
        assert_nil step.run
      end
    end
    refute_executed_beyond_sudo_probe
  end

  def test_continues_after_denied_formula_and_reports_each_failed_package
    stub_non_admin
    write_config(:brew, "brew_casks" => ["ghostty"])
    @fake_system.stub_command(mise_status_command, '{"brew":{"packages":[{"package":"duti"},{"package":"fish"}]}}')
    %w[duti fish].each { |name| @fake_system.stub_command(list_command("formula", name), "", exit_status: 1) }
    @fake_system.stub_command(list_command("cask", "ghostty"), "", exit_status: 1)
    @fake_system.stub_command(install_command("formula", "duti"), "denied by policy", exit_status: 1)
    @fake_system.stub_command(install_command("formula", "fish"), "not allowed", exit_status: 1)

    step.run

    assert_cask_installed(install_command("cask", "ghostty", private_appdir: true))
    assert_equal 2, @fake_system.operations.count { |operation| Dotfiles::Command.display(operation[1]).include?("brew install --formula duti") }
    assert_incomplete
    assert_includes step.errors.join("\n"), "duti"
    assert_includes step.errors.join("\n"), "denied by policy"
    assert_includes step.errors.join("\n"), "fish"
    assert_includes step.errors.join("\n"), "not allowed"
    assert_includes step.errors.join("\n"), "ghostty"
  end

  def test_does_not_install_formulae_for_admin_user
    stub_admin
    write_config(:brew, "brew_casks" => ["ghostty"])
    step.run
    refute_executed(mise_status_command)
    refute_executed(install_command("formula", "duti"))
  end

  def test_omits_formulae_when_mise_status_is_unusable
    stub_non_admin
    write_config(:brew, "brew_casks" => [])
    [["bad", 0], ["{}", 1]].each do |output, status|
      @fake_system.stub_command(mise_status_command, output, exit_status: status)
      step.instance_variable_set(:@formulae, nil)
      refute_should_run
    end
  end

  def test_complete_reports_missing_package_without_attempted_install
    stub_admin
    write_config(:brew, "brew_casks" => ["ghostty"])
    @fake_system.stub_command(list_command("cask", "ghostty"), "", exit_status: 1)

    assert_should_run
    assert_incomplete
    assert_includes step.errors.join("\n"), "Homebrew cask not installed: ghostty"
  end

  def test_complete_skips_homebrew_when_no_packages_are_needed
    stub_admin
    write_config(:brew, "brew_casks" => [])

    assert_complete
    refute_executed(list_command("cask", "ghostty"))
  end

  private

  def assert_cask_installed(command)
    options = {quiet: true, timeout: Dotfiles::Step::InstallBrewCasksStep::CASK_INSTALL_TIMEOUT_SECONDS}
    assert @fake_system.received_operation?(:execute, command, options), "Expected cask install `#{command}` with a timeout"
  end

  def stub_admin
    @fake_system.stub_macos
    @fake_system.stub_command(["groups"], "admin staff")
  end

  def stub_non_admin
    @fake_system.stub_macos
    @fake_system.stub_command(["groups"], "staff")
  end

  def mise_status_command
    "mise -C #{@home} bootstrap packages status --json 2>&1"
  end

  def mise_status_json
    '{"brew":{"packages":[{"package":"duti"}]}}'
  end

  def update_command
    "HOMEBREW_NO_ENV_HINTS=1 brew update-if-needed"
  end

  def list_command(type, name)
    "HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew list --#{type} --versions #{name} 2>&1"
  end

  def install_command(type, name, private_appdir: false)
    adopt = (type == "cask") ? " --adopt" : ""
    appdir = private_appdir ? " --appdir=#{@home}/Applications" : ""
    "HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew install --#{type}#{adopt}#{appdir} #{name} 2>&1"
  end
end
