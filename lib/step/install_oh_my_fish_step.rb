class InstallOhMyFishStep < Step
  def self.depends_on
    [InstallBrewPackagesStep, CloneDotfilesStep]
  end
  def run
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

  def complete?
    omf_dir = File.expand_path('~/.local/share/omf')
    omf_config = File.expand_path('~/.config/omf')

    Dir.exist?(omf_dir) && Dir.exist?(omf_config)
  end
end