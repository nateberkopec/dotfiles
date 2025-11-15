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
    each_file_in(source_dir) do |src_path, relative_path|
      dest_path = File.join(@home, relative_path)
      ensure_parent_exists(dest_path)
      copy_if_different(src_path, dest_path)
    end
  end

  def sync_from_home_to_repo
    each_file_in(source_dir) do |repo_path, relative_path|
      home_path = File.join(@home, relative_path)
      next unless @system.file_exist?(home_path)
      ensure_parent_exists(repo_path)
      copy_if_different(home_path, repo_path)
    end
  end

  def find_out_of_sync_files
    out_of_sync = []
    each_file_in(source_dir) do |src_path, relative_path|
      dest_path = File.join(@home, relative_path)
      unless file_in_sync?(src_path, dest_path)
        out_of_sync << {src: src_path, dest: dest_path, relative: relative_path}
      end
    end
    out_of_sync
  end

  def each_file_in(dir)
    return unless @system.dir_exist?(dir)
    @system.glob(File.join(dir, "**", "{*,.*}"), File::FNM_DOTMATCH).each do |path|
      next unless @system.file_exist?(path)
      next if @system.dir_exist?(path)
      relative_path = path.sub("#{dir}/", "")
      yield path, relative_path
    end
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
