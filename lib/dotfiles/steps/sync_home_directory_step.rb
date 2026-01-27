class Dotfiles::Step::SyncHomeDirectoryStep < Dotfiles::Step
  prepend Dotfiles::Step::Sudoable

  def self.display_name
    "Home Directory Files"
  end

  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep]
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
    !find_out_of_sync_files.empty?
  end

  def update
    debug "Updating home directory files from system..."
    sync_all_files(from_system: true)
  end

  private

  def source_dir
    File.join(@dotfiles_dir, "files", "home")
  end

  def sync_all_files(from_system: false)
    if from_system
      sync_from_home_to_repo
    else
      sync_from_repo_to_home
    end
  end

  def sync_from_repo_to_home
    each_file_in(source_dir).each { |src, _, dest| sync_file(src, dest) }
    each_symlink_in(source_dir).each { |src, _, dest| sync_symlink(src, dest) }
  end

  def sync_from_home_to_repo
    each_file_in(source_dir).each { |repo, _, dest| sync_file(dest, repo) if @system.file_exist?(dest) }
    each_symlink_in(source_dir).each { |repo, _, dest| sync_symlink(dest, repo) if @system.symlink?(dest) }
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
    files = find_out_of_sync(each_file_in(source_dir)) { |src, _, dest| file_in_sync?(src, dest) }
    symlinks = find_out_of_sync(each_symlink_in(source_dir)) { |src, _, dest| symlink_in_sync?(src, dest) }
    files + symlinks
  end

  def find_out_of_sync(entries, &block)
    entries.reject(&block).map { |src, rel, dest| {src: src, dest: dest, relative: rel} }
  end

  def symlink_in_sync?(source, dest)
    @system.symlink?(dest) && @system.readlink(dest) == @system.readlink(source)
  end

  def each_file_in(dir)
    each_entry_in(dir, all_files_in(dir))
  end

  def each_symlink_in(dir)
    each_entry_in(dir, all_symlinks_in(dir))
  end

  def each_entry_in(dir, paths)
    return [] unless @system.dir_exist?(dir)

    paths.map { |path| [path, path.sub("#{dir}/", ""), File.join(@home, path.sub("#{dir}/", ""))] }
  end

  def all_files_in(dir)
    glob_entries(dir).select { |p| @system.file_exist?(p) && !@system.dir_exist?(p) && !@system.symlink?(p) }
  end

  def all_symlinks_in(dir)
    glob_entries(dir).select { |path| @system.symlink?(path) }
  end

  def glob_entries(dir)
    @system.glob(File.join(dir, "**", "{*,.*}"), File::FNM_DOTMATCH)
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
    _, status = execute("chflags noschg '#{file}'", sudo: true)
    raise Errno::EPERM, "Failed to remove immutable flag from #{file}" unless status == 0
  end
end
