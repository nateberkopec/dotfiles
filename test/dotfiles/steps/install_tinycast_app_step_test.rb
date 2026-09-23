require "test_helper"

class InstallTinycastAppStepTest < StepTestCase
  step_class Dotfiles::Step::InstallTinycastAppStep

  def test_should_not_run_by_default
    refute_should_run
  end

  def test_complete_by_default
    assert_complete
  end

  def test_has_no_step_dependencies
    assert_empty self.class.step_class.depends_on
  end

  def test_should_run_when_tinycast_is_not_in_applications
    stub_mise_tinycast

    assert_should_run
  end

  def test_complete_when_tinycast_is_installed_and_not_quarantined
    stub_mise_tinycast
    stub_installed_app
    @fake_system.stub_command(quarantine_check_command, "", exit_status: 1)

    assert_complete
  end

  def test_incomplete_when_tinycast_is_quarantined
    stub_mise_tinycast
    stub_installed_app
    @fake_system.stub_command(quarantine_check_command, "0081;", exit_status: 0)

    assert_incomplete
  end

  def test_run_copies_release_and_clears_quarantine_for_admin_user
    stub_mise_tinycast(admin: true)

    step.run

    assert_executed(["/usr/bin/ditto", source_app, "/Applications/Tinycast.app"])
    assert_executed(["/usr/bin/xattr", "-dr", "com.apple.quarantine", "/Applications/Tinycast.app"])
  end

  def test_run_uses_user_applications_for_non_admin_user
    stub_mise_tinycast

    step.run

    assert_executed(["/usr/bin/ditto", source_app, destination_app])
    assert_executed(["/usr/bin/xattr", "-dr", "com.apple.quarantine", destination_app])
  end

  def test_run_preserves_an_existing_self_updated_app
    stub_mise_tinycast
    stub_installed_app

    step.run

    refute_executed(["/usr/bin/ditto", source_app, destination_app])
    assert_executed(["/usr/bin/xattr", "-dr", "com.apple.quarantine", destination_app])
  end

  private

  def stub_mise_tinycast(admin: false)
    @fake_system.stub_macos
    @fake_system.stub_command("groups", admin ? "admin staff" : "staff")
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 0)
    @fake_system.stub_command(mise_where_command, install_dir, exit_status: 0)
    @fake_system.stub_file_content(File.join(source_app, "Contents", "Info.plist"), "plist")
  end

  def stub_installed_app
    @fake_system.stub_file_content(File.join(destination_app, "Contents", "Info.plist"), "plist")
  end

  def mise_where_command
    "mise --cd #{@home} where github:abue-ammar/tinycast"
  end

  def install_dir
    File.join(@home, ".local", "share", "mise", "installs", "github-abue-ammar-tinycast", "0.11.3")
  end

  def source_app
    File.join(install_dir, "Tinycast.app")
  end

  def destination_app
    File.join(@home, "Applications", "Tinycast.app")
  end

  def quarantine_check_command
    ["/usr/bin/xattr", "-p", "com.apple.quarantine", destination_app]
  end
end
