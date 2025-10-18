class Dotfiles::Step::InstallOhMyFishStep < Dotfiles::Step
  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep, Dotfiles::Step::CloneDotfilesStep]
  end

  def run
    omf_dir = File.expand_path("~/.local/share/omf")
    if Dir.exist?(omf_dir)
      debug "oh-my-fish already installed, skipping..."
    else
      debug "Installing oh-my-fish..."
      execute("curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install > install")
      execute('fish -c "fish install --noninteractive"')
      FileUtils.rm("install")
    end

    debug "Configuring oh-my-fish..."
    omf_config_dir = File.expand_path("~/.config/omf")
    FileUtils.mkdir_p(omf_config_dir)
    FileUtils.cp_r(Dir.glob("#{@dotfiles_dir}/omf/*"), omf_config_dir)

    execute('fish -c "omf install"')
  end

  def complete?
    omf_dir = File.expand_path("~/.local/share/omf")
    omf_config = File.expand_path("~/.config/omf")

    Dir.exist?(omf_dir) && Dir.exist?(omf_config)
  end

  # Sync OMF configs back into dotfiles repo
  def update
    omf_config_dir = File.expand_path("~/.config/omf")
    dest_dir = File.join(@dotfiles_dir, "files", "omf")

    return unless Dir.exist?(omf_config_dir)

    FileUtils.mkdir_p(dest_dir)

    %w[Dotfiles::Step::bundle, Dotfiles::Step::channel, Dotfiles::Step::theme].each do |file|
      src = File.join(omf_config_dir, file)
      dest = File.join(dest_dir, file)
      FileUtils.cp(src, dest) if File.exist?(src)
    end
  end
end
