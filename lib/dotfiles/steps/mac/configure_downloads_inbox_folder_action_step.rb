class Dotfiles::Step::ConfigureDownloadsInboxFolderActionStep < Dotfiles::Step
  DESCRIPTION = "Compiles and records the Folder Action that moves Downloads items into Inbox.".freeze

  macos_only

  def self.depends_on
    [Dotfiles::Step::CreateStandardFoldersStep]
  end

  def should_run?
    return false if ENV["CI"]
    super
  end

  def run
    install_compiled_script unless compiled_script_current?
    enable_folder_actions unless folder_actions_enabled?
    return if attachment_current?

    add_notice(
      title: "Attach the Downloads folder action",
      message: <<~MESSAGE.strip
        Open Folder Actions Setup manually and attach #{collapse_path_to_home(compiled_script_path)} to Downloads.
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
    execute(command("osacompile", "-o", compiled_script_path, source_path))
    @system.write_file(source_digest_path, source_digest)
  end

  def enable_folder_actions
    execute(command("defaults", "write", "com.apple.FolderActionsDispatcher", "folderActionsEnabled", "-bool", "true"))
  end

  def folder_actions_enabled?
    output, status = execute(command("defaults", "read", "com.apple.FolderActionsDispatcher", "folderActionsEnabled"))
    status == 0 && ["1", "true", "YES"].include?(output.strip)
  end

  def attachment_current?
    return false unless @system.file_exist?(folder_actions_preferences_path)

    preferences = @system.read_file(folder_actions_preferences_path).b
    [downloads_path, compiled_script_path].all? { |path| preferences.include?(path.downcase.b) }
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

  def folder_actions_preferences_path
    File.join(@home, "Library/Preferences/com.apple.FolderActionsDispatcher.plist")
  end

  def downloads_path
    File.join(@home, "Downloads")
  end
end
