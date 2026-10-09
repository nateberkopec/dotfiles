require "test_helper"

class InstallMiseAppsStepTest < StepTestCase
  step_class Dotfiles::Step::InstallMiseAppsStep

  def test_skips_non_macos_hosts
    refute_should_run
    assert_complete
  end

  def test_has_no_step_dependencies
    assert_empty self.class.step_class.depends_on
  end

  def test_runs_when_apps_are_missing
    stub_releases
    assert_should_run
  end

  def test_complete_when_apps_are_installed_and_not_quarantined
    stub_releases
    stub_installed_apps
    assert_complete
  end

  def test_incomplete_when_an_app_is_quarantined
    stub_releases
    stub_installed_apps
    @fake_system.stub_command(quarantine_check("CodexBar"), "0081;", exit_status: 0)
    assert_incomplete
  end

  def test_installs_releases_for_admin_users
    stub_releases(admin: true)
    step.run
    each_app do |name, _|
      assert_executed(["/usr/bin/codesign", "--verify", "--deep", "--strict", source(name)])
      assert_executed(["/usr/bin/ditto", source(name), "/Applications/#{name}.app"])
      assert_executed(["/usr/bin/xattr", "-dr", "com.apple.quarantine", "/Applications/#{name}.app"])
    end
  end

  def test_installs_releases_for_non_admin_users
    stub_releases
    step.run
    each_app do |name, _|
      assert_executed(["/usr/bin/codesign", "--verify", "--deep", "--strict", source(name)])
      assert_executed(["/usr/bin/ditto", source(name), destination(name)])
      assert_executed(["/usr/bin/xattr", "-dr", "com.apple.quarantine", destination(name)])
    end
  end

  def test_preserves_existing_self_updated_apps_and_preferences
    stub_releases
    stub_installed_apps
    step.run
    each_app { |name, _| refute_executed(["/usr/bin/ditto", source(name), destination(name)]) }
    assert_empty step.notices
  end

  def test_reports_missing_releases
    @fake_system.stub_macos
    step.run
    each_app { |name, _| assert_includes step.errors, "Mise-managed #{name} release not found" }
  end

  private

  def each_app(&block)
    {"Tinycast" => "github:abue-ammar/tinycast", "CodexBar" => "github:steipete/CodexBar", "OrbStack" => "aqua:dotfiles/orbstack"}.each(&block)
  end

  def stub_releases(admin: false)
    @fake_system.stub_macos
    @fake_system.stub_command("groups", admin ? "admin staff" : "staff")
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 0)
    each_app do |name, tool|
      @fake_system.stub_command("mise --cd #{@home} where #{tool}", File.dirname(source(name)), exit_status: 0)
      @fake_system.stub_file_content(File.join(source(name), "Contents", "Info.plist"), "plist")
    end
  end

  def stub_installed_apps
    each_app do |name, _|
      @fake_system.stub_file_content(File.join(destination(name), "Contents", "Info.plist"), "plist")
      @fake_system.stub_command(quarantine_check(name), "", exit_status: 1)
    end
  end

  def source(name)
    File.join(@home, ".local/share/mise/installs", name.downcase, "release", "#{name}.app")
  end

  def destination(name)
    File.join(@home, "Applications", "#{name}.app")
  end

  def quarantine_check(name)
    ["/usr/bin/xattr", "-p", "com.apple.quarantine", destination(name)]
  end
end
