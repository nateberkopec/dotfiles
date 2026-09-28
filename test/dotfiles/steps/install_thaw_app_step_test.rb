require "test_helper"

class InstallThawAppStepTest < StepTestCase
  step_class Dotfiles::Step::InstallThawAppStep

  def test_should_not_run_by_default
    refute_should_run
  end

  def test_should_run_when_app_is_not_in_applications
    stub_mise_thaw

    assert_should_run
  end

  def test_complete_when_installed
    stub_mise_thaw
    stub_installed_app

    assert_complete
  end

  def test_install_for_admin_user
    stub_mise_thaw(admin: true)

    step.run

    assert @fake_system.operations.any? { |op| op.first == :execute && op[1].is_a?(Array) && op[1][0..1] == ["/usr/bin/ditto", File.join(mountpoint, "Thaw.app")] && op[1].last == "/Applications/Thaw.app" }
    assert_executed(["/usr/bin/hdiutil", "detach", mountpoint])
  end

  def test_install_for_non_admin_user
    stub_mise_thaw

    step.run

    assert_executed(["/usr/bin/ditto", File.join(mountpoint, "Thaw.app"), destination_app])
  end

  def test_preserves_self_updated_app
    stub_mise_thaw
    stub_installed_app

    step.run

    refute @fake_system.operations.any? { |op| op.first == :execute && op[1].is_a?(Array) && op[1].first == "/usr/bin/hdiutil" }
  end

  def test_does_not_copy_when_mount_fails
    stub_mise_thaw
    mountpoint = "/tmp/test-thaw-mount"
    step.define_singleton_method(:temp_path) { |_label| mountpoint }
    @fake_system.stub_command(["/usr/bin/hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", mountpoint, source_image], "failed", exit_status: 1)

    assert_raises(RuntimeError) { step.run }
    refute @fake_system.operations.any? { |op| op.first == :execute && op[1].is_a?(Array) && op[1].first == "/usr/bin/ditto" }
  end

  def test_reports_missing_mise_release
    @fake_system.stub_macos

    step.run

    assert_includes step.errors, "Mise-managed Thaw release not found"
  end

  private

  def stub_mise_thaw(admin: false)
    @fake_system.stub_macos
    @fake_system.stub_command("groups", admin ? "admin staff" : "staff")
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 0)
    @fake_system.stub_command("mise --cd #{@home} where github:thaw-app/Thaw", install_dir, exit_status: 0)
    @fake_system.stub_file_content(source_image, "dmg")
  end

  def stub_installed_app
    @fake_system.stub_file_content(File.join(destination_app, "Contents", "Info.plist"), "plist")
  end

  def install_dir
    File.join(@home, ".local", "share", "mise", "installs", "github-thaw-app-Thaw", "2.0.1")
  end

  def source_image
    File.join(install_dir, "Thaw.dmg")
  end

  def mountpoint
    attach = @fake_system.operations.find { |op| op.first == :execute && op[1].is_a?(Array) && op[1][0..1] == ["/usr/bin/hdiutil", "attach"] }
    attach[1][-2]
  end

  def destination_app
    File.join(@home, "Applications", "Thaw.app")
  end
end
