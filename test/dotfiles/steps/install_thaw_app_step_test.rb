require "test_helper"

class InstallThawAppStepTest < StepTestCase
  step_class Dotfiles::Step::InstallThawAppStep

  def test_should_run_when_missing_on_admin_mac
    stub_admin

    assert_should_run
  end

  def test_non_admin_does_not_download_or_install
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "staff")

    refute_should_run
    assert_complete
    step.run
    refute @fake_system.operations.any? { |op| op.first == :execute && op[1].is_a?(Array) && op[1].first == "curl" }
  end

  def test_ci_does_not_download_release
    stub_admin

    with_ci do
      refute_should_run
      assert_complete
      step.run
    end

    refute @fake_system.operations.any? { |op| op.first == :execute && op[1].is_a?(Array) && op[1].first == "curl" }
  end

  def test_complete_when_installed
    stub_admin
    stub_installed_app

    assert_complete
  end

  def test_downloads_verifies_and_installs_on_admin_mac
    stub_admin
    stub_checksum

    step.run

    assert_executed(["curl", "-fsSL", "--retry", "2", "-o", image, Dotfiles::Step::InstallThawAppStep::URL])
    assert_executed(["/usr/bin/codesign", "--verify", "--deep", "--strict", File.join(mountpoint, "Thaw.app")])
    assert_executed(["/usr/bin/ditto", File.join(mountpoint, "Thaw.app"), "/Applications/Thaw.app"])
    assert_executed(["/usr/bin/hdiutil", "detach", mountpoint])
    assert_includes step.notices.first[:message], "Thaw keeps your profiles and preferences locally"
  end

  def test_does_not_mount_image_when_checksum_mismatches
    stub_admin
    @fake_system.stub_command(["/usr/bin/shasum", "-a", "256", image], "wrong  #{image}", exit_status: 0)

    assert_raises(RuntimeError) { step.run }
    refute @fake_system.operations.any? { |op| op.first == :execute && op[1].is_a?(Array) && op[1].first == "/usr/bin/hdiutil" }
  end

  def test_does_not_copy_when_mount_fails
    stub_admin
    stub_checksum
    @fake_system.stub_command(["/usr/bin/hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", mountpoint, image], "failed", exit_status: 1)

    assert_raises(RuntimeError) { step.run }
    refute @fake_system.operations.any? { |op| op.first == :execute && op[1].is_a?(Array) && op[1].first == "/usr/bin/ditto" }
  end

  def test_preserves_existing_self_updated_app
    stub_admin
    stub_installed_app

    step.run

    refute @fake_system.operations.any? { |op| op.first == :execute && op[1].is_a?(Array) && op[1].first == "curl" }
  end

  private

  def stub_admin
    @fake_system.stub_macos
    @fake_system.stub_command("groups", "admin staff")
    step.define_singleton_method(:temp_path) { |label| "/tmp/test-#{label}" }
  end

  def stub_checksum
    @fake_system.stub_command(["/usr/bin/shasum", "-a", "256", image], "#{Dotfiles::Step::InstallThawAppStep::SHA256}  #{image}", exit_status: 0)
  end

  def stub_installed_app
    @fake_system.stub_file_content("/Applications/Thaw.app/Contents/Info.plist", "plist")
  end

  def image
    "/tmp/test-thaw-release.dmg"
  end

  def mountpoint
    "/tmp/test-thaw-mount"
  end
end
