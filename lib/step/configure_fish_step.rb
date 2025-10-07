class ConfigureFishStep < Step
  def self.depends_on
    [InstallBrewPackagesStep, CloneDotfilesStep]
  end

  def run
    debug "Setting up Fish configuration..."
    fish_config_dir = @config.expand_path("fish_config_dir")
    FileUtils.mkdir_p(fish_config_dir)

    FileUtils.cp(@config.source_path("fish_config"), fish_config_dir)
    FileUtils.cp_r(@config.source_path("fish_functions"), fish_config_dir)
  end

  def complete?
    fish_config = @config.expand_path("fish_config_file")
    fish_functions = @config.expand_path("fish_functions_dir")

    File.exist?(fish_config) && Dir.exist?(fish_functions)
  end

  # Sync current Fish config back into dotfiles
  def update
    fish_config_file = @config.expand_path("fish_config_file")
    fish_functions_dir = @config.expand_path("fish_functions_dir")

    dest_config = @config.source_path("fish_config")
    dest_functions = @config.source_path("fish_functions")

    return unless fish_config_file && fish_functions_dir && dest_config && dest_functions

    FileUtils.mkdir_p(File.dirname(dest_config))
    FileUtils.cp(fish_config_file, dest_config) if File.exist?(fish_config_file)

    FileUtils.mkdir_p(dest_functions)
    if Dir.exist?(fish_functions_dir)
      Dir.glob(File.join(fish_functions_dir, "*")) do |src|
        FileUtils.cp(src, File.join(dest_functions, File.basename(src))) if File.file?(src)
      end
    end
  end
end
