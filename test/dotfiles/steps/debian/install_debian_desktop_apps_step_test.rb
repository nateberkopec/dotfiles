require "test_helper"
class InstallDebianDesktopAppsStepTest < StepTestCase
  step_class Dotfiles::Step::InstallDebianDesktopAppsStep
  SourceInstaller = Struct.new(:result, :installed) { define_method(:install) { |source| (installed << source) && result } }
  def test_public_methods_do_nothing_by_default
    refute_should_run
    assert_complete
    assert_nil step.run
  end

  def test_installs_configured_missing_package_after_ensuring_source
    configure_app
    installer = SourceInstaller.new(true, [])
    step(source_installer: installer).run
    assert_equal ["example"], installer.installed.map { |app| app["name"] }
    assert_executed "sudo apt-get update -y"
    assert_executed "sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y example-app"
  end

  def test_source_failure_stops_package_installation
    configure_app
    installer = SourceInstaller.new(false, [])
    current_step = step(source_installer: installer)
    current_step.run
    assert_equal ["example"], installer.installed.map { |app| app["name"] }
    assert_includes current_step.errors.tap { current_step.complete? }, "Failed to install a Debian desktop application source"
    refute_executed "sudo apt-get update -y"
    refute_executed "sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y example-app"
  end

  def test_update_failure_stops_package_installation
    configure_app
    @fake_system.stub_command("sudo apt-get update -y", "network error", exit_status: 1)
    current_step = step(source_installer: SourceInstaller.new(true, []))

    current_step.run

    assert_includes current_step.errors.tap { current_step.complete? }.join("\n"), "network error"
    refute_executed "sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y example-app"
  end

  def test_skips_in_ci_and_container
    configure_app
    with_ci do
      refute_should_run
      assert_complete
      assert_nil step.run
    end
    @fake_system.stub_running_container
    refute_should_run
    assert_complete
    assert_nil step.run
    refute @fake_system.received_operation?(:execute)
  end

  private

  def configure_app
    @fake_system.stub_debian
    app = {"name" => "example", "package" => "example-app", "key_url" => "https://example.invalid/key", "line" => "deb https://example.invalid stable main"}
    write_config("config", "debian_desktop_apps" => [app])
    @fake_system.stub_command("dpkg -s example-app >/dev/null 2>&1", "", exit_status: 1)
  end
end
