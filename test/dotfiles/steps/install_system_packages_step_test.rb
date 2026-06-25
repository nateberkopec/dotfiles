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

  def test_should_not_run_when_brew_packages_are_installed
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "admin staff")
    write_config(:brew, {"brew" => {"packages" => ["duti"], "casks" => []}})
    stub_brew_package_installed("duti")

    refute_should_run
  end

  def test_should_run_when_brew_package_is_missing
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "admin staff")
    write_config(:brew, {"brew" => {"packages" => ["duti"], "casks" => []}})
    stub_brew_package_missing("duti")

    assert_should_run
  end

  def test_checks_brew_packages_in_bulk
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "admin staff")
    write_config(:brew, {"brew" => {"packages" => ["duti", "trash"], "casks" => []}})
    stub_brew_packages_installed("duti", "trash")

    refute_should_run

    assert_equal 1, brew_list_versions_count
  end

  def test_should_run_when_one_brew_package_is_missing
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "admin staff")
    write_config(:brew, {"brew" => {"packages" => ["duti", "trash"], "casks" => []}})
    stub_brew_packages_installed("duti", missing: ["trash"])

    assert_should_run
  end

  def test_should_not_run_when_apt_packages_are_installed
    @fake_system.stub_debian
    write_config("config", "packages" => {"trash" => {"debian" => "trash-cli"}})
    stub_apt_package_installed("trash-cli")

    refute_should_run
  end

  def test_should_run_when_apt_package_is_missing
    @fake_system.stub_debian
    write_config("config", "packages" => {"trash" => {"debian" => "trash-cli"}})
    stub_apt_package_missing("trash-cli")

    assert_should_run
  end

  def test_run_installs_brew_packages_with_mise_on_macos
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "admin staff")
    write_config(:brew, {"brew" => {"packages" => ["duti"], "casks" => []}})
    stub_brew_package_missing("duti")

    step.run

    assert_executed("MISE_EXPERIMENTAL=1 mise system install --yes --update brew:duti")
  end

  def test_run_installs_apt_packages_with_mise_on_debian
    @fake_system.stub_debian
    write_config("config", "packages" => {"trash" => {"debian" => "trash-cli"}})
    stub_apt_package_missing("trash-cli")

    step.run

    assert_executed("MISE_EXPERIMENTAL=1 mise system install --yes --update apt:trash-cli")
  end

  def test_falls_back_to_brew_when_mise_system_is_unavailable
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "admin staff")
    @fake_system.stub_command("MISE_EXPERIMENTAL=1 mise system install --help", "no task system found", exit_status: 1)
    write_config(:brew, {"brew" => {"packages" => ["duti"], "casks" => []}})
    stub_brew_package_missing("duti")

    step.run

    assert_executed("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew install duti")
  end

  def test_falls_back_to_apt_when_mise_system_is_unavailable
    @fake_system.stub_debian
    @fake_system.stub_command("MISE_EXPERIMENTAL=1 mise system install --help", "no task system found", exit_status: 1)
    write_config("config", "packages" => {"trash" => {"debian" => "trash-cli"}})
    stub_apt_package_missing("trash-cli")

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
    stub_brew_package_missing("duti")
    @fake_system.stub_command("MISE_EXPERIMENTAL=1 mise system install --yes --update brew:duti", "boom", exit_status: 1)

    step.run

    refute step.complete?
    assert_includes step.errors.join("\n"), "mise system install"
  end

  private

  def stub_brew_package_installed(package)
    stub_brew_packages_installed(package)
  end

  def stub_brew_package_missing(package)
    stub_brew_packages_installed(missing: [package])
  end

  def stub_brew_packages_installed(*installed, missing: [])
    packages = installed + missing
    output = installed.map { |package| "#{package} 1.0.0" }.join("\n")
    @fake_system.stub_command(
      "HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew list --formula --versions #{packages.join(" ")}",
      output,
      exit_status: missing.empty? ? 0 : 1
    )
  end

  def brew_list_versions_count
    @fake_system.operations.count do |operation, command, _options|
      operation == :execute && Dotfiles::Command.display(command).include?("brew list --formula --versions")
    end
  end

  def stub_apt_package_installed(package)
    stub_apt_package_check(package, exit_status: 0)
  end

  def stub_apt_package_missing(package)
    stub_apt_package_check(package, exit_status: 1)
  end

  def stub_apt_package_check(package, exit_status:)
    @fake_system.stub_command("dpkg -s #{package}", "", exit_status: exit_status)
  end
end
