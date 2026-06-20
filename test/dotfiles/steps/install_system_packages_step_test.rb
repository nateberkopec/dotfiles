require "test_helper"

class InstallSystemPackagesStepTest < StepTestCase
  step_class Dotfiles::Step::InstallSystemPackagesStep

  def test_depends_on_debian_sources
    assert_equal [Dotfiles::Step::InstallDebianPackagesStep], self.class.step_class.depends_on
  end

  def test_should_not_run_by_default
    refute_should_run
  end

  def test_complete_by_default
    assert_complete
  end

  def test_run_installs_brew_packages_with_mise_on_macos
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "admin staff")
    write_config(:brew, {"brew" => {"packages" => ["duti"], "casks" => []}})

    step.run

    assert_executed("mise system install --yes --update brew:duti")
  end

  def test_run_installs_apt_packages_with_mise_on_debian
    @fake_system.stub_debian
    write_config("config", "packages" => {"trash" => {"debian" => "trash-cli"}})

    step.run

    assert_executed("mise system install --yes --update apt:trash-cli")
  end

  def test_falls_back_to_brew_when_mise_system_is_unavailable
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "admin staff")
    @fake_system.stub_command("mise help system", "no task system found", exit_status: 1)
    write_config(:brew, {"brew" => {"packages" => ["duti"], "casks" => []}})

    step.run

    assert_executed("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew install duti")
  end

  def test_falls_back_to_apt_when_mise_system_is_unavailable
    @fake_system.stub_debian
    @fake_system.stub_command("mise help system", "no task system found", exit_status: 1)
    write_config("config", "packages" => {"trash" => {"debian" => "trash-cli"}})

    step.run

    assert_executed("sudo env DEBIAN_FRONTEND=noninteractive apt-get update -y")
    assert_executed("sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y trash-cli")
  end

  def test_macos_non_admin_leaves_brew_packages_for_homebrew_step
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "staff")
    write_config(:brew, {"brew" => {"packages" => ["duti"], "casks" => []}})

    refute_should_run
  end

  def test_excludes_non_apt_packages
    @fake_system.stub_debian
    write_config(
      "config",
      "packages" => {"droid" => {"debian" => "droid"}},
      "debian_non_apt_packages" => ["droid"]
    )

    refute_should_run
  end

  def test_records_mise_failures
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "admin staff")
    write_config(:brew, {"brew" => {"packages" => ["duti"], "casks" => []}})
    @fake_system.stub_command("mise system install --yes --update brew:duti", "boom", exit_status: 1)

    step.run

    refute step.complete?
    assert_includes step.errors.join("\n"), "mise system install"
  end
end
