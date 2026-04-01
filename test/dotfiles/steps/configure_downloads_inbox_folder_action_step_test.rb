require "digest"
require "test_helper"

class ConfigureDownloadsInboxFolderActionStepTest < StepTestCase
  step_class Dotfiles::Step::ConfigureDownloadsInboxFolderActionStep

  def setup
    super
    @fake_system.stub_macos
    install_source_script
  end

  def test_should_run_when_compiled_script_is_missing
    stub_folder_actions_enabled
    stub_unattached

    assert_should_run
  end

  def test_should_not_run_when_compiled_script_is_current_and_attached
    install_current_compiled_script
    stub_folder_actions_enabled
    stub_attached

    refute_should_run
  end

  def test_run_compiles_script_and_writes_digest
    run_unattached_with_folder_actions_disabled

    assert_command_run(:mkdir_p, File.dirname(compiled_script_path))
    assert_executed(compile_command)
    assert_equal Digest::MD5.hexdigest(@fake_system.read_file(source_path)), @fake_system.read_file(source_digest_path)
  end

  def test_run_enables_folder_actions_when_disabled
    run_unattached_with_folder_actions_disabled

    assert_executed(enable_command)
  end

  def test_run_reveals_script_and_opens_setup_when_unattached
    run_unattached_with_folder_actions_disabled

    assert_executed(reveal_command, quiet: false)
    assert_executed(open_setup_command, quiet: false)
    notice = step.notices.first
    assert notice, "Expected a notice when the folder action still needs attaching"
    assert_includes notice[:message], "Move Downloads to Inbox.scpt"
  end

  def test_run_skips_ui_when_attachment_is_current
    install_current_compiled_script
    stub_folder_actions_enabled
    stub_attached

    step.run

    refute_executed(reveal_command, quiet: false)
    refute_executed(open_setup_command, quiet: false)
  end

  def test_complete_when_compiled_script_is_current_and_attached
    install_current_compiled_script
    stub_folder_actions_enabled
    stub_attached

    assert_complete
  end

  def test_incomplete_when_attachment_is_missing
    install_current_compiled_script
    stub_folder_actions_enabled
    stub_unattached

    assert_incomplete
  end

  def test_ci_env_skips_configuration
    with_ci do
      refute_should_run
      assert_complete
    end
  end

  private

  def run_unattached_with_folder_actions_disabled
    stub_folder_actions_disabled
    stub_unattached
    step.run
  end

  def compile_command
    "osacompile -o #{compiled_script_path.shellescape} #{source_path.shellescape}"
  end

  def enable_command
    "defaults write com.apple.FolderActionsDispatcher folderActionsEnabled -bool true"
  end

  def reveal_command
    "open -R #{compiled_script_path.shellescape}"
  end

  def open_setup_command
    "open -a 'Folder Actions Setup' #{downloads_path.shellescape}"
  end

  def install_source_script
    @fake_system.mkdir_p(File.dirname(source_path))
    @fake_system.write_file(source_path, "on adding folder items to this_folder after receiving added_items\nend adding folder items to\n")
  end

  def install_current_compiled_script
    @fake_system.write_file(compiled_script_path, "compiled")
    @fake_system.write_file(source_digest_path, Digest::MD5.hexdigest(@fake_system.read_file(source_path)))
  end

  def stub_folder_actions_enabled
    @fake_system.stub_command("defaults read com.apple.FolderActionsDispatcher folderActionsEnabled", "1", 0)
  end

  def stub_folder_actions_disabled
    @fake_system.stub_command("defaults read com.apple.FolderActionsDispatcher folderActionsEnabled", "0", 0)
  end

  def stub_attached
    @fake_system.stub_command(downloads_scripts_query, compiled_script_path, 0)
  end

  def stub_unattached
    @fake_system.stub_command(downloads_scripts_query, "", 1)
  end

  def downloads_scripts_query
    "osascript -e 'tell application \"Folder Actions Setup\" to get POSIX path of every script of folder action \"Downloads\"'"
  end

  def source_path
    File.join(@home, ".local/share/folder-actions/move-downloads-to-inbox.applescript")
  end

  def compiled_script_path
    File.join(@home, "Library/Scripts/Folder Action Scripts/Move Downloads to Inbox.scpt")
  end

  def source_digest_path
    File.join(@home, "Library/Scripts/Folder Action Scripts/Move Downloads to Inbox.source.md5")
  end

  def downloads_path
    File.join(@home, "Downloads")
  end
end
