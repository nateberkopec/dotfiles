class Dotfiles::Step::InstallOhMyFishStep < Dotfiles::Step
  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep]
  end

  def run
    omf_dir = File.expand_path("~/.local/share/omf")
    if @system.dir_exist?(omf_dir)
      debug "oh-my-fish already installed, skipping..."
    else
      debug "Installing oh-my-fish..."
      execute("curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install > install")
      execute('fish -c "fish install --noninteractive"')
      @system.rm_rf("install")
    end

    debug "Configuring oh-my-fish..."
    omf_config_dir = File.expand_path("~/.config/omf")
    @system.mkdir_p(omf_config_dir)
    @system.cp_r(@system.glob("#{@dotfiles_dir}/omf/*"), omf_config_dir)

    execute('fish -c "omf install"')
  end

  def complete?
    omf_dir = File.expand_path("~/.local/share/omf")
    omf_config = File.expand_path("~/.config/omf")

    @system.dir_exist?(omf_dir) && @system.dir_exist?(omf_config)
  end

  # Sync OMF configs back into dotfiles repo
  def update
    omf_config_dir = File.expand_path("~/.config/omf")
    dest_dir = File.join(@dotfiles_dir, "files", "omf")

    return unless @system.dir_exist?(omf_config_dir)

    @system.mkdir_p(dest_dir)

    %w[Dotfiles::Step::bundle, Dotfiles::Step::channel, Dotfiles::Step::theme].each do |file|
      src = File.join(omf_config_dir, file)
      dest = File.join(dest_dir, file)
      @system.cp(src, dest) if @system.file_exist?(src)
    end
  end
end
