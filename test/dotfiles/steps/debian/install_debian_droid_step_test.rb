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
    @fake_system.stub_debian
    stub_droid_missing
    write_config("config", "debian_non_apt_packages" => ["droid"])

    assert_should_run
  end

  def test_incomplete_when_configured_and_missing
    @fake_system.stub_debian
    stub_droid_missing
    write_config("config", "debian_non_apt_packages" => ["droid"])

    assert_incomplete
  end

  private

  def stub_droid_missing
    @fake_system.stub_command("command -v droid >/dev/null 2>&1", "", exit_status: 1)
  end
end
