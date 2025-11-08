require "test_helper"

class ConfigureDropboxStepTest < StepTestCase
  step_class Dotfiles::Step::ConfigureDropboxStep

  def test_should_run_when_installed_but_not_configured
    install_dropbox
    assert_should_run
  end

  def test_should_not_run_when_not_installed
    refute_should_run
  end

  def test_should_not_run_when_already_configured
    install_dropbox
    configure_dropbox
    refute_should_run
  end

  def test_complete_when_dropbox_folder_exists
    configure_dropbox
    assert_complete
  end

  def test_complete_when_cloud_storage_folder_exists
    configure_cloud_storage
    assert_complete
  end

  def test_incomplete_when_installed_but_missing_folder
    install_dropbox
    assert_incomplete
  end

  def test_complete_when_not_installed
    assert_complete
  end

  def test_run_launches_dropbox_and_adds_notice
    install_dropbox
    step.run

    assert_executed("open -a Dropbox")
    notice = step.notices.first
    assert notice, "Expected notice after running step"
    assert_includes notice[:title], "Dropbox"
  end

  private

  def dropbox_app_path
    "/Applications/Dropbox.app"
  end

  def dropbox_home_path
    File.join(@home, "Dropbox")
  end

  def dropbox_cloud_path
    File.join(@home, "Library", "CloudStorage", "Dropbox")
  end

  def install_dropbox
    @fake_system.filesystem[dropbox_app_path] = :directory
  end

  def configure_dropbox
    @fake_system.filesystem[dropbox_home_path] = :directory
  end

  def configure_cloud_storage
    @fake_system.filesystem[dropbox_cloud_path] = :directory
  end
end
