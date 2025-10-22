class Dotfiles::Step::ConfigureFishStep < Dotfiles::Step
  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep]
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

    return false unless fish_config_file && fish_functions_dir
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

    # Sync config.fish if it has changed
    @system.mkdir_p(File.dirname(dest_config))
    if @system.file_exist?(fish_config_file) && !files_match?(fish_config_file, dest_config)
      @system.cp(fish_config_file, dest_config)
    end

    # Sync functions directory
    @system.mkdir_p(dest_functions)
    if @system.dir_exist?(fish_functions_dir)
      # Copy all fish functions from system to repo, but only if they've changed
      @system.glob(File.join(fish_functions_dir, "*.fish")).each do |src|
        dest = File.join(dest_functions, File.basename(src))
        # Copy if destination doesn't exist or files don't match
        if !@system.file_exist?(dest) || !files_match?(src, dest)
          @system.cp(src, dest)
        end
      end

      # Remove functions from repo that no longer exist on system
      system_functions = @system.glob(File.join(fish_functions_dir, "*.fish")).map { |f| File.basename(f) }
      @system.glob(File.join(dest_functions, "*.fish")).each do |repo_file|
        basename = File.basename(repo_file)
        @system.rm_rf(repo_file) unless system_functions.include?(basename)
      end
    end
  end

  private

  def directories_match?(source_dir, dest_dir)
    source_files = @system.glob(File.join(source_dir, "*")).sort
    dest_files = @system.glob(File.join(dest_dir, "*")).sort

    return false unless source_files.map { |f| File.basename(f) } == dest_files.map { |f| File.basename(f) }

    source_files.zip(dest_files).all? do |source, dest|
      files_match?(source, dest)
    end
  end
end
