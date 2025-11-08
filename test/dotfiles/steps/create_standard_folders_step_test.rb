require "test_helper"

class CreateStandardFoldersStepTest < Minitest::Test
  def test_run_creates_all_folders
    step = create_step_with_folders(["Documents/Inbox", "Documents/Code.nosync"])
    step.run
    assert @fake_system.received_operation?(:mkdir_p, "#{@home}/Documents/Inbox")
    assert @fake_system.received_operation?(:mkdir_p, "#{@home}/Documents/Code.nosync")
  end

  def test_complete_when_all_folders_exist
    step = create_step_with_folders(["Documents/Inbox", "Documents/Code.nosync"])
    @fake_system.mkdir_p("#{@home}/Documents/Inbox")
    @fake_system.mkdir_p("#{@home}/Documents/Code.nosync")
    assert step.complete?
  end

  def test_incomplete_when_any_folder_missing
    step = create_step_with_folders(["Documents/Inbox", "Documents/Code.nosync"])
    @fake_system.mkdir_p("#{@home}/Documents/Inbox")
    refute step.complete?
  end

  def test_complete_returns_true_when_no_folders_configured
    step = create_step_with_folders([])
    assert step.complete?
  end

  def test_run_handles_existing_folders_gracefully
    step = create_step_with_folders(["Documents/Inbox"])
    @fake_system.mkdir_p("#{@home}/Documents/Inbox")
    step.run
    assert @fake_system.received_operation?(:mkdir_p, "#{@home}/Documents/Inbox")
  end

  def test_run_creates_nested_folders
    step = create_step_with_folders(["Documents/Code.nosync/business"])
    step.run
    assert @fake_system.received_operation?(:mkdir_p, "#{@home}/Documents/Code.nosync/business")
  end

  private

  def create_step_with_folders(folders)
    step = create_step(Dotfiles::Step::CreateStandardFoldersStep)
    step.config.load_config("folders.yml")
    stub_folders_config(step, folders)
    step
  end

  def stub_folders_config(step, folders)
    @fake_system.stub_file_content(
      "#{@dotfiles_dir}/config/folders.yml",
      YAML.dump({"standard_folders" => folders})
    )
    step.instance_variable_set(:@folders_config, nil)
    step.instance_variable_set(:@standard_folders, nil)
  end
end
