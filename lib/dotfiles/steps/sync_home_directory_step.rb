class Dotfiles::Step::SyncHomeDirectoryStep < Dotfiles::Step
  DESCRIPTION = "Syncs tracked home-directory files and symlinks into your home folder.".freeze

  prepend Dotfiles::Step::Sudoable

  def self.display_name
    "Home Directory Files"
  end

  def self.depends_on
    Dotfiles::Step.system_packages_steps
  end

  def run
    debug "Syncing home directory files..."
    sync_all_files
  end

  def complete?
    super
    out_of_sync = find_out_of_sync_files
    out_of_sync.each { |file| add_error("File not in sync: #{collapse_path_to_home(file[:dest])}") }
    out_of_sync.empty?
  end

  def should_run?
    out_of_sync = find_out_of_sync_files
    debug_out_of_sync(out_of_sync)
    !out_of_sync.empty?
  end

  private

  def effective_entries
    home_file_set.entries
  end

  def home_file_set
    @home_file_set ||= Dotfiles::HomeFileSet.new(dotfiles_dir: @dotfiles_dir, home: @home, system: @system)
  end

  def sync_all_files
    effective_entries.each { |entry| sync_entry(entry) }
  end

  def sync_entry(entry)
    handle_entry(entry, file_action: method(:sync_file), symlink_action: method(:sync_symlink))
  end

  def sync_file(from, to)
    ensure_parent_exists(to)
    copy_if_different(from, to)
  end

  def sync_symlink(from, to)
    ensure_parent_exists(to)
    target = @system.readlink(from)
    return if symlink_matches?(to, target)

    @system.rm_rf(to)
    @system.create_symlink(target, to)
  end

  def symlink_matches?(path, expected_target)
    @system.symlink?(path) && @system.readlink(path) == expected_target
  end

  def find_out_of_sync_files
    effective_entries.reject { |entry| entry_in_sync?(entry) }
  end

  def entry_in_sync?(entry)
    handle_entry(entry, file_action: method(:file_in_sync?), symlink_action: method(:symlink_in_sync?))
  end

  def handle_entry(entry, file_action:, symlink_action:)
    source, dest = entry.values_at(:src, :dest)
    action = (entry[:type] == :file) ? file_action : symlink_action
    action.call(source, dest)
  end

  def symlink_in_sync?(source, dest)
    @system.symlink?(dest) && @system.readlink(dest) == @system.readlink(source)
  end

  def file_in_sync?(source_file, dest_file)
    @system.file_exist?(dest_file) && files_match?(source_file, dest_file)
  end

  def ensure_parent_exists(path)
    @system.mkdir_p(File.dirname(path))
  end

  def copy_if_different(from, to)
    return if files_match?(from, to)

    begin
      @system.cp(from, to)
    rescue Errno::EPERM
      remove_immutable_flag(to)
      @system.cp(from, to)
    end
  end

  def remove_immutable_flag(file)
    _, status = execute(command("chflags", "nouchg", file), quiet: false)
    return if status == 0

    _, status = execute(command("chflags", "nouchg,noschg", file), quiet: false, sudo: true)
    raise Errno::EPERM, "Failed to remove immutable flag from #{file}" unless status == 0
  end

  def debug_out_of_sync(out_of_sync)
    return unless @debug
    return if out_of_sync.empty?
    items = out_of_sync.map { |file| collapse_path_to_home(file[:dest]) }
    debug "Home directory files out of sync: #{items.join(", ")}"
  end
end
