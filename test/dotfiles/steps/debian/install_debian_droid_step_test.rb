require "test_helper"

class InstallDebianDroidStepTest < StepTestCase
  step_class Dotfiles::Step::InstallDebianDroidStep

  def test_should_not_run_by_default
    refute_should_run
  end

  def test_complete_by_default
    assert_complete
  end

  def test_should_run_when_configured_and_missing
    configure_missing_droid

    assert_should_run
  end

  def test_run_installs_when_configured
    configure_missing_droid

    step.run

    assert_executed(droid_install_command)
  end

  def test_run_skips_when_not_configured
    @fake_system.stub_debian
    stub_droid_missing

    step.run

    refute_executed(droid_install_command)
  end

  def test_incomplete_when_configured_and_missing
    configure_missing_droid

    refute step.complete?
    assert_includes step.errors, "Non-APT package not installed: droid"
  end

  def test_complete_when_installed
    @fake_system.stub_debian
    stub_droid_installed
    write_config("config", "debian_non_apt_packages" => ["droid"])

    assert_complete
  end

  private

  def configure_missing_droid
    @fake_system.stub_debian
    stub_droid_missing
    write_config("config", "debian_non_apt_packages" => ["droid"])
  end

  def stub_droid_missing
    @fake_system.stub_command("command -v droid >/dev/null 2>&1", "", exit_status: 1)
  end

  def stub_droid_installed
    @fake_system.stub_command("command -v droid >/dev/null 2>&1", "", exit_status: 0)
  end

  def droid_install_command
    ["bash", "-c", 'curl -fsSL "$1" | "$2"', "dotfiles", "https://app.factory.ai/cli", "sh"]
  end
end
