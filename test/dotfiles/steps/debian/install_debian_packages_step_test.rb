require "test_helper"

class InstallDebianPackagesStepTest < StepTestCase
  step_class Dotfiles::Step::InstallDebianPackagesStep

  def test_should_not_run_by_default
    refute_should_run
  end

  def test_complete_by_default
    assert_complete
  end

  def test_should_run_when_package_missing
    stub_package_missing("ripgrep")
    write_config(
      "config",
      "packages" => {
        "ripgrep" => {"debian" => "ripgrep"}
      }
    )

    assert_should_run
  end

  def test_incomplete_when_package_missing
    stub_package_missing("ripgrep")
    write_config(
      "config",
      "packages" => {
        "ripgrep" => {"debian" => "ripgrep"}
      }
    )

    assert_incomplete
  end

  def test_reports_apt_install_failure
    stub_package_missing("ripgrep")
    write_config(
      "config",
      "packages" => {
        "ripgrep" => {"debian" => "ripgrep"}
      }
    )

    @fake_system.stub_command("sudo DEBIAN_FRONTEND=noninteractive apt-get update -y", "", exit_status: 0)
    @fake_system.stub_command(
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ripgrep",
      "E: Unable to locate package ripgrep",
      exit_status: 100
    )

    step.run

    refute step.complete?
    assert_includes step.errors, "apt-get install failed (status 100): E: Unable to locate package ripgrep"
  end

  private

  def stub_package_missing(name)
    @fake_system.stub_command("dpkg -s #{name} >/dev/null 2>&1", "", exit_status: 1)
    @fake_system.stub_command("apt-cache show #{name} >/dev/null 2>&1", "", exit_status: 0)
  end
end
