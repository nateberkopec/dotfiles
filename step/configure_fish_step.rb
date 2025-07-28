class ConfigureFishStep < Step
  def run
    debug 'Setting up Fish configuration...'
    fish_config_dir = File.expand_path('~/.config/fish')
    FileUtils.mkdir_p(fish_config_dir)

    FileUtils.cp("#{@dotfiles_dir}/fish/config.fish", fish_config_dir)
    FileUtils.cp_r("#{@dotfiles_dir}/fish/functions", fish_config_dir)
  end

  def complete?
    fish_config = File.expand_path('~/.config/fish/config.fish')
    fish_functions = File.expand_path('~/.config/fish/functions')

    File.exist?(fish_config) && Dir.exist?(fish_functions)
  end
end