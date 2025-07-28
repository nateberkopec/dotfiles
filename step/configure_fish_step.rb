class ConfigureFishStep < Step
  def run
    debug 'Setting up Fish configuration...'
    fish_config_dir = @config.expand_path('fish_config_dir')
    FileUtils.mkdir_p(fish_config_dir)

    FileUtils.cp(@config.source_path('fish_config'), fish_config_dir)
    FileUtils.cp_r(@config.source_path('fish_functions'), fish_config_dir)
  end

  def complete?
    fish_config = @config.expand_path('fish_config_file')
    fish_functions = @config.expand_path('fish_functions_dir')

    File.exist?(fish_config) && Dir.exist?(fish_functions)
  end
end