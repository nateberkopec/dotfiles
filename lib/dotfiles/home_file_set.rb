class Dotfiles::HomeFileSet
  IGNORED_RELATIVE_PATHS = [
    ".config/fish/fish_variables",
    ".pi/agent/auth.json"
  ].freeze

  def initialize(dotfiles_dir:, home:, system:)
    @dotfiles_dir = dotfiles_dir
    @home = home
    @system = system
  end

  def entries
    source_dirs.each_with_object({}) { |dir, by_relative| add_entries(by_relative, dir) }
      .values
      .sort_by { |entry| entry[:relative] }
  end

  private

  def source_dirs
    [source_dir("home"), platform_source_dir, host_source_dir].compact.select { |dir| @system.dir_exist?(dir) }
  end

  def platform_source_dir
    if @system.macos?
      source_dir("home.macos")
    elsif @system.linux?
      source_dir("home.linux")
    end
  end

  def host_source_dir
    hostname = @system.hostname.to_s
    source_dir(File.join("home.hosts", hostname)) unless hostname.empty?
  end

  def source_dir(name)
    File.join(@dotfiles_dir, "files", name)
  end

  def add_entries(by_relative, dir)
    files_in(dir).each { |path| add_entry(by_relative, :file, dir, path) }
    symlinks_in(dir).each { |path| add_entry(by_relative, :symlink, dir, path) }
  end

  def add_entry(by_relative, type, dir, path)
    relative = path.sub("#{dir}/", "")
    by_relative[relative] = {type: type, src: path, dest: File.join(@home, relative), relative: relative}
  end

  def files_in(dir)
    entries_in(dir).select { |path| @system.file_exist?(path) && !@system.dir_exist?(path) && !@system.symlink?(path) }
  end

  def symlinks_in(dir)
    entries_in(dir).select { |path| @system.symlink?(path) }
  end

  def entries_in(dir)
    @system.glob(File.join(dir, "**", "{*,.*}"), File::FNM_DOTMATCH)
      .reject { |path| IGNORED_RELATIVE_PATHS.include?(path.sub("#{dir}/", "")) }
  end
end
