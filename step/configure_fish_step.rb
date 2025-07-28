class ConfigureFishStep < Step
  def run
    debug 'Setting up Fish configuration...'
    fish_config_dir = File.expand_path('~/.config/fish')
    FileUtils.mkdir_p(fish_config_dir)

    FileUtils.cp("#{@dotfiles_dir}/fish/config.fish", fish_config_dir)
    FileUtils.cp_r("#{@dotfiles_dir}/fish/functions", fish_config_dir)

    install_oh_my_fish
  end

  def complete?
    fish_config = File.expand_path('~/.config/fish/config.fish')
    fish_functions = File.expand_path('~/.config/fish/functions')
    omf_dir = File.expand_path('~/.local/share/omf')
    omf_config = File.expand_path('~/.config/omf')

    File.exist?(fish_config) && Dir.exist?(fish_functions) &&
    Dir.exist?(omf_dir) && Dir.exist?(omf_config)
  end

  private

  def install_oh_my_fish
    omf_dir = File.expand_path('~/.local/share/omf')
    unless Dir.exist?(omf_dir)
      debug 'Installing oh-my-fish...'
      execute('curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install > install')
      execute('fish -c "fish install --noninteractive"')
      FileUtils.rm('install')
    else
      debug 'oh-my-fish already installed, skipping...'
    end

    debug 'Configuring oh-my-fish...'
    omf_config_dir = File.expand_path('~/.config/omf')
    FileUtils.mkdir_p(omf_config_dir)
    FileUtils.cp_r(Dir.glob("#{@dotfiles_dir}/omf/*"), omf_config_dir)

    execute('fish -c "omf install"')
  end
end