class Dotfiles::Step::CloneDotfilesStep < Dotfiles::Step
  def run
    if @system.dir_exist?(@config.dotfiles_dir)
      debug "Dotfiles directory already exists, pulling latest changes..."
      @system.chdir(@config.dotfiles_dir) { execute("git pull") }
    else
      debug "Cloning dotfiles repository..."
      execute("git clone #{@config.dotfiles_repo} #{@config.dotfiles_dir}")
    end
  end

  def complete?
    @system.dir_exist?(@config.dotfiles_dir) && @system.dir_exist?(File.join(@config.dotfiles_dir, ".git"))
  end
end
