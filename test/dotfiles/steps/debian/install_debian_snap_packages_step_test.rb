require "test_helper"

class InstallDebianSnapPackagesStepTest < StepTestCase
  step_class Dotfiles::Step::InstallDebianSnapPackagesStep

  def test_should_not_run_by_default
    refute_should_run
  end

  def test_complete_by_default
    assert_complete
  end

  def test_should_run_when_configured_and_missing
    @fake_system.stub_debian
    stub_snap_available
    stub_snap_missing("ghostty")
    write_config("config", "debian_snap_packages" => [{"name" => "ghostty", "classic" => true}])

    assert_should_run
  end

  def test_incomplete_when_configured_and_missing
    @fake_system.stub_debian
    stub_snap_available
    stub_snap_missing("ghostty")
    write_config("config", "debian_snap_packages" => [{"name" => "ghostty", "classic" => true}])

    assert_incomplete
  end

  def test_skips_snap_packages_in_container
    @fake_system.stub_debian
    @fake_system.stub_running_container
    stub_snap_available
    stub_snap_missing("ghostty")
    write_config("config", "debian_snap_packages" => [{"name" => "ghostty", "classic" => true}])

    refute_should_run
    assert_complete
  end

  private

  def stub_snap_available
    @fake_system.stub_command("command -v snap >/dev/null 2>&1", "", exit_status: 0)
  end

  def stub_snap_missing(name)
    @fake_system.stub_command("snap list #{name} >/dev/null 2>&1", "", exit_status: 1)
  end
end
