class Dotfiles::Step::SyncConfigDirectoryStep < Dotfiles::Step
  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep]
  end

  def run
    debug "Syncing config directory items..."
    config_items.each { |item| sync_to_home(item) }
  end

  def complete?
    config_items.all? { |item| item_in_sync?(item) }
  end

  def should_run?
    config_items.any? { |item| !item_in_sync?(item) }
  end

  def update
    config_items.each { |item| sync_from_home(item) }
  end

  private

  def config_items
    @config_items ||= @config.config_sync.fetch("config_directory_items", [])
  end

  def sync_to_home(item)
    copy_item(
      from: source_path(item),
      to: home_config_path(item),
      item_name: item
    )
  end

  def sync_from_home(item)
    from = home_config_path(item)
    to = source_path(item)

    if directory_item?(item)
      return unless @system.dir_exist?(from)
      @system.mkdir_p(to)
      copy_all_files(from, to)
      remove_deleted_files(from: from, to: to)
    else
      return unless @system.file_exist?(from)
      ensure_parent_exists(to)
      copy_if_different(from, to)
    end
  end

  def copy_item(from:, to:, item_name:)
    if directory_item?(item_name)
      debug "Syncing directory: #{item_name}"
      @system.mkdir_p(to)
      copy_all_files(from, to)
    else
      debug "Syncing file: #{item_name}"
      ensure_parent_exists(to)
      copy_if_different(from, to)
    end
  end

  def item_in_sync?(item)
    source = source_path(item)
    dest = home_config_path(item)

    if directory_item?(item)
      directory_in_sync?(source, dest)
    else
      file_in_sync?(source, dest)
    end
  end

  def directory_in_sync?(source_dir, dest_dir)
    return false unless @system.dir_exist?(dest_dir)

    source_files = files_in_directory(source_dir)
    dest_files = files_in_directory(dest_dir)

    return false unless source_files.keys.sort == dest_files.keys.sort

    source_files.all? do |relative_path, source_file|
      files_match?(source_file, dest_files[relative_path])
    end
  end

  def file_in_sync?(source_file, dest_file)
    @system.file_exist?(dest_file) && files_match?(source_file, dest_file)
  end

  def copy_all_files(from_dir, to_dir)
    each_file_in(from_dir) do |src, relative_path|
      dest = @system.path_join(to_dir, relative_path)
      ensure_parent_exists(dest)
      copy_if_different(src, dest)
    end
  end

  def remove_deleted_files(from:, to:)
    from_files = files_in_directory(from)
    to_files = files_in_directory(to)

    to_files.each do |relative_path, file_path|
      @system.rm_rf(file_path) unless from_files.key?(relative_path)
    end
  end

  def each_file_in(dir)
    @system.glob(@system.path_join(dir, "**", "*")).each do |path|
      next unless @system.file_exist?(path)
      relative_path = path.sub("#{dir}/", "")
      yield path, relative_path
    end
  end

  def files_in_directory(dir)
    {}.tap do |files|
      each_file_in(dir) { |path, rel| files[rel] = path }
    end
  end

  def directory_item?(item)
    item.end_with?("/") || @system.dir_exist?(source_path(item))
  end

  def ensure_parent_exists(path)
    @system.mkdir_p(@system.path_dirname(path))
  end

  def copy_if_different(from, to)
    @system.cp(from, to) unless files_match?(from, to)
  end

  def source_path(item)
    clean_item_path(item, @dotfiles_dir, "files", "config")
  end

  def home_config_path(item)
    clean_item_path(item, @home, ".config")
  end

  def clean_item_path(item, *path_parts)
    clean_item = item.sub(%r{/$}, "")
    @system.path_join(*path_parts, clean_item)
  end
end
