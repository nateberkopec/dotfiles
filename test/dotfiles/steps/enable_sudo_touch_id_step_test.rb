require "test_helper"

class EnableSudoTouchIDStepTest < StepTestCase
  step_class Dotfiles::Step::EnableSudoTouchIDStep

  def setup
    super
    @fake_system.stub_macos
  end

  def test_incomplete_when_sudo_local_is_missing
    assert_incomplete
  end

  def test_complete_when_touch_id_is_enabled
    @fake_system.stub_file_content(target_path, "auth       sufficient     pam_tid.so\n")

    assert_complete
  end

  def test_run_installs_sudo_local
    step.run

    assert_executed(
      ["sudo", "install", "-o", "root", "-g", "wheel", "-m", "0444", source_path, target_path],
      quiet: false
    )
  end

  def test_run_reports_install_failure
    command = ["sudo", "install", "-o", "root", "-g", "wheel", "-m", "0444", source_path, target_path]
    @fake_system.stub_command(command, "permission denied", 1)

    step.run

    assert_includes step.errors, "Failed to enable Touch ID for sudo"
  end

  def test_run_refuses_to_replace_existing_sudo_local
    @fake_system.stub_file_content(target_path, "auth required pam_opendirectory.so\n")

    step.run

    assert_includes step.errors, "Refusing to replace existing #{target_path}"
    refute_executed ["sudo", "install", "-o", "root", "-g", "wheel", "-m", "0444", source_path, target_path]
  end

  def test_complete_in_ci_when_sudo_local_is_missing
    with_ci { assert_complete }
  end

  def test_does_not_run_off_macos
    @fake_system.stub_macos(false)

    refute_should_run
  end

  private

  def source_path
    File.join(@dotfiles_dir, "files", "templates", "sudo_local")
  end

  def target_path
    "/etc/pam.d/sudo_local"
  end
end
