class Dotfiles::Step::ConfigureFishStep < Dotfiles::Step
  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep, Dotfiles::Step::CloneDotfilesStep]
  end

  def run
    debug "Setting up Fish configuration..."
    fish_config_dir = home_path("fish_config_dir")
    fish_config_file = home_path("fish_config_file")
    fish_functions_dir = home_path("fish_functions_dir")

    @system.mkdir_p(fish_config_dir)

    @system.cp(dotfiles_source("fish_config"), fish_config_file)

    @system.mkdir_p(fish_functions_dir)
    @system.rm_rf(@system.glob(File.join(fish_functions_dir, "*")))
    @system.glob(File.join(dotfiles_source("fish_functions"), "*")).each do |src|
      @system.cp(src, fish_functions_dir)
    end
  end

  def complete?
    fish_config_file = home_path("fish_config_file")
    fish_functions_dir = home_path("fish_functions_dir")

    return false unless @system.file_exist?(fish_config_file) && @system.dir_exist?(fish_functions_dir)

    source_config = dotfiles_source("fish_config")
    source_functions = dotfiles_source("fish_functions")

    config_matches = files_match?(source_config, fish_config_file)
    functions_match = directories_match?(source_functions, fish_functions_dir)

    config_matches && functions_match
  end

  # Sync current Fish config back into dotfiles
  def update
    fish_config_file = home_path("fish_config_file")
    fish_functions_dir = home_path("fish_functions_dir")

    dest_config = dotfiles_source("fish_config")
    dest_functions = dotfiles_source("fish_functions")

    return unless fish_config_file && fish_functions_dir && dest_config && dest_functions

    @system.mkdir_p(File.dirname(dest_config))
    @system.cp(fish_config_file, dest_config) if @system.file_exist?(fish_config_file)

    @system.mkdir_p(dest_functions)
    if @system.dir_exist?(fish_functions_dir)
      @system.glob(File.join(fish_functions_dir, "*")) do |src|
        @system.cp(src, File.join(dest_functions, File.basename(src))) if @system.file_exist?(src)
      end
    end
  end

  private

  def files_match?(source_file, dest_file)
    return false unless @system.file_exist?(dest_file)
    file_hash(source_file) == file_hash(dest_file)
  end

  def directories_match?(source_dir, dest_dir)
    source_files = @system.glob(File.join(source_dir, "*")).sort
    dest_files = @system.glob(File.join(dest_dir, "*")).sort

    return false unless source_files.map { |f| File.basename(f) } == dest_files.map { |f| File.basename(f) }

    source_files.zip(dest_files).all? do |source, dest|
      files_match?(source, dest)
    end
  end

  def file_hash(file_path)
    require "digest"
    Digest::SHA256.hexdigest(@system.read_file(file_path))
  end
end
