require "test_helper"

class CreateStandardFoldersStepTest < StepTestCase
  step_class Dotfiles::Step::CreateStandardFoldersStep

  def setup
    super
    set_standard_folders("Documents/Inbox", "Documents/Code.nosync")
  end

  def test_run_creates_all_folders
    step.run
    assert_command_run(:mkdir_p, File.join(@home, "Documents/Inbox"))
    assert_command_run(:mkdir_p, File.join(@home, "Documents/Code.nosync"))
  end

  def test_run_handles_existing_folders
    @fake_system.mkdir_p(File.join(@home, "Documents/Inbox"))
    step.run

    assert_command_run(:mkdir_p, File.join(@home, "Documents/Inbox"))
  end

  def test_run_creates_nested_paths
    set_standard_folders("Documents/Code.nosync/business")
    step.run
    assert_command_run(:mkdir_p, File.join(@home, "Documents/Code.nosync/business"))
  end

  def test_complete_when_all_folders_exist
    create_folders("Documents/Inbox", "Documents/Code.nosync")
    assert_complete
  end

  def test_incomplete_when_any_folder_missing
    create_folders("Documents/Inbox")
    assert_incomplete
  end

  def test_complete_when_no_folders_configured
    set_standard_folders
    assert_complete
  end

  private

  def set_standard_folders(*folders)
    write_config("folders", {"standard_folders" => folders})
    reset_step_cache(step, :@folders_config, :@standard_folders) if defined?(@step) && @step
  end

  def create_folders(*folders)
    folders.each do |folder|
      @fake_system.mkdir_p(File.join(@home, folder))
    end
  end
end
