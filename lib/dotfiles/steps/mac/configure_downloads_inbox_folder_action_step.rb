require "shellwords"

class Dotfiles::Step::ConfigureDownloadsInboxFolderActionStep < Dotfiles::Step
  macos_only

  def self.depends_on
    [Dotfiles::Step::CreateStandardFoldersStep, Dotfiles::Step::SyncHomeDirectoryStep]
  end

  def should_run?
    return false if ENV["CI"]
    super
  end

  def run
    install_compiled_script unless compiled_script_current?
    enable_folder_actions unless folder_actions_enabled?
    return if attachment_current?

    reveal_compiled_script
    open_folder_action_setup
    add_notice(
      title: "Attach the Downloads folder action",
      message: <<~MESSAGE.strip
        Attach #{collapse_path_to_home(compiled_script_path)} to Downloads in Folder Actions Setup.
        Once it is attached, rerun dotfiles and this step should go green.
      MESSAGE
    )
  end

  def complete?
    return true if ENV["CI"]

    super
    add_error("Folder action source missing at #{collapse_path_to_home(source_path)}") unless @system.file_exist?(source_path)
    add_error("Compiled folder action missing or stale at #{collapse_path_to_home(compiled_script_path)}") unless compiled_script_current?
    add_error("Folder Actions are disabled") unless folder_actions_enabled?
    add_error("Folder action not attached to Downloads: #{collapse_path_to_home(compiled_script_path)}") unless attachment_current?
    @errors.empty?
  end

  private

  def install_compiled_script
    @system.mkdir_p(File.dirname(compiled_script_path))
    execute("osacompile -o #{Shellwords.escape(compiled_script_path)} #{Shellwords.escape(source_path)}")
    @system.write_file(source_digest_path, source_digest)
  end

  def enable_folder_actions
    execute("defaults write com.apple.FolderActionsDispatcher folderActionsEnabled -bool true")
  end

  def reveal_compiled_script
    execute("open -R #{Shellwords.escape(compiled_script_path)}", quiet: false)
  end

  def open_folder_action_setup
    execute("open -a 'Folder Actions Setup' #{Shellwords.escape(downloads_path)}", quiet: false)
  end

  def folder_actions_enabled?
    output, status = execute("defaults read com.apple.FolderActionsDispatcher folderActionsEnabled")
    status == 0 && ["1", "true", "YES"].include?(output.strip)
  end

  def attachment_current?
    output, status = execute(downloads_scripts_query)
    return false unless status == 0

    output.split(/,\s*/).include?(compiled_script_path)
  end

  def downloads_scripts_query
    "osascript -e 'tell application \"Folder Actions Setup\" to get POSIX path of every script of folder action \"Downloads\"'"
  end

  def source_digest
    file_hash(source_path).to_s
  end

  def compiled_script_current?
    @system.file_exist?(compiled_script_path) && @system.file_exist?(source_digest_path) && @system.read_file(source_digest_path) == source_digest
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
