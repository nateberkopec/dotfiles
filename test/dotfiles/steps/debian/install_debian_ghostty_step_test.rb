require "test_helper"

class InstallDebianGhosttyStepTest < StepTestCase
  step_class Dotfiles::Step::InstallDebianGhosttyStep

  def test_should_not_run_by_default
    refute_should_run
  end

  def test_complete_by_default
    assert_complete
  end

  def test_depends_on_mise_tools
    assert_includes self.class.step_class.depends_on, Dotfiles::Step::InstallMiseToolsStep
  end

  def test_should_run_when_mise_appimage_is_not_wrapped
    stub_debian_mise_ghostty
    stub_wrapper_missing

    assert_should_run
  end

  def test_complete_when_mise_appimage_is_wrapped
    stub_debian_mise_ghostty
    stub_wrapper_installed

    assert_complete
  end

  def test_incomplete_when_mise_appimage_is_not_wrapped
    stub_debian_mise_ghostty
    stub_wrapper_missing

    assert_incomplete
  end

  def test_run_wraps_mise_installed_appimage_without_downloading
    stub_debian_mise_ghostty
    stub_wrapper_missing

    step.run

    assert_equal "appimage-binary", @fake_system.read_file(backup_path)
    assert_includes @fake_system.read_file(appimage_path), "--appimage-extract-and-run"
    refute @fake_system.operations.any? { |operation| operation.any? { |arg| arg.to_s.include?("curl") } }
  end

  private

  def stub_debian_mise_ghostty
    @fake_system.stub_debian
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 0)
    @fake_system.stub_command("mise --cd #{@home} where github:pkgforge-dev/ghostty-appimage", install_dir, exit_status: 0)
    @fake_system.stub_file_content(appimage_path, "appimage-binary")
  end

  def stub_wrapper_missing
    @fake_system.stub_command(wrapper_check_command, "", exit_status: 1)
  end

  def stub_wrapper_installed
    @fake_system.stub_command(wrapper_check_command, "# dotfiles ghostty AppImage wrapper", exit_status: 0)
  end

  def wrapper_check_command
    ["head", "-n", "2", appimage_path]
  end

  def install_dir
    File.join(@home, ".local", "share", "mise", "installs", "github-pkgforge-dev-ghostty-appimage", "latest")
  end

  def appimage_path
    File.join(install_dir, "ghostty")
  end

  def backup_path
    File.join(install_dir, "ghostty.AppImage")
  end
end
