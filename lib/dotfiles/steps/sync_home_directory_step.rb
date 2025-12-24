class Dotfiles::Step::SyncHomeDirectoryStep < Dotfiles::Step
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
  end

  def sync_from_home_to_repo
    each_file_in(source_dir).each { |repo, _, dest| sync_file(dest, repo) if @system.file_exist?(dest) }
  end

  def sync_file(from, to)
    ensure_parent_exists(to)
    copy_if_different(from, to)
  end

  def find_out_of_sync_files
    each_file_in(source_dir)
      .reject { |src, _, dest| file_in_sync?(src, dest) }
      .map { |src, rel, dest| {src: src, dest: dest, relative: rel} }
  end

  def each_file_in(dir)
    return [] unless @system.dir_exist?(dir)
    all_files_in(dir).map { |path| [path, path.sub("#{dir}/", ""), File.join(@home, path.sub("#{dir}/", ""))] }
  end

  def all_files_in(dir)
    @system.glob(File.join(dir, "**", "{*,.*}"), File::FNM_DOTMATCH)
      .select { |path| @system.file_exist?(path) && !@system.dir_exist?(path) }
  end

  def file_in_sync?(source_file, dest_file)
    @system.file_exist?(dest_file) && files_match?(source_file, dest_file)
  end

  def ensure_parent_exists(path)
    @system.mkdir_p(File.dirname(path))
  end

  def copy_if_different(from, to)
    @system.cp(from, to) unless files_match?(from, to)
  end
end
