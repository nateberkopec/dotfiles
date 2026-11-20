require "test_helper"

class InstallBrewFormulaeStepTest < StepTestCase
  step_class Dotfiles::Step::InstallBrewFormulaeStep

  def test_has_no_step_dependencies
    assert_empty self.class.step_class.depends_on
  end

  def test_non_admin_installs_formulae
    stub_non_admin
    @fake_system.stub_command(mise_status_command, mise_status_json)
    @fake_system.stub_command(list_command("formula"), "", exit_status: 1)

    assert_should_run
    assert_incomplete
    step.run

    assert_executed(install_command("formula", "duti"))
  end

  def test_non_admin_packages_remain_eligible_in_ci
    stub_non_admin
    with_env("CI" => "true", "NONINTERACTIVE" => nil) do
      @fake_system.stub_command(mise_status_command, mise_status_json)
      @fake_system.stub_command(list_command("formula"), "", exit_status: 1)

      assert_should_run
      assert_incomplete
      step.run

      assert_executed(install_command("formula", "duti"))
    end
  end

  def test_noninteractive_without_passwordless_sudo_skips_all_homebrew_operations
    stub_non_admin
    stub_sudo_requires_password
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
    @fake_system.stub_command(mise_status_command, '{"brew":{"packages":[{"package":"duti"},{"package":"fish"}]}}')
    @fake_system.stub_command(list_command("formula"), "", exit_status: 1)
    @fake_system.stub_command(install_command("formula", "duti"), "denied by policy", exit_status: 1)
    @fake_system.stub_command(install_command("formula", "fish"), "not allowed", exit_status: 1)

    step.run

    assert_equal 2, @fake_system.operations.count { |operation| Dotfiles::Command.display(operation[1]).include?("brew install --formula duti") }
    assert_incomplete
    assert_includes step.errors.join("\n"), "duti"
    assert_includes step.errors.join("\n"), "denied by policy"
    assert_includes step.errors.join("\n"), "fish"
    assert_includes step.errors.join("\n"), "not allowed"
  end

  def test_does_not_install_formulae_for_admin_user
    stub_admin
    step.run
    refute_executed(mise_status_command)
    refute_executed(install_command("formula", "duti"))
  end

  def test_omits_formulae_when_mise_status_is_unusable
    stub_non_admin
    [["bad", 0], ["{}", 1]].each do |output, status|
      @fake_system.stub_command(mise_status_command, output, exit_status: status)
      step.instance_variable_set(:@formulae, nil)
      refute_should_run
    end
  end

  def test_complete_skips_homebrew_when_no_packages_are_needed
    stub_admin

    assert_complete
    refute_executed(list_command("formula"))
  end

  private

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

  def list_command(type)
    "HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew list --#{type} -1 2>&1"
  end

  def install_command(type, name)
    "HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew install --#{type} #{name} 2>&1"
  end
end
