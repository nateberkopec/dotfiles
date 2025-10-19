class Dotfiles::Step::CloneDotfilesStep < Dotfiles::Step
  def run
    if @system.dir_exist?(@dotfiles_dir)
      debug "Dotfiles directory already exists, pulling latest changes..."
      @system.chdir(@dotfiles_dir) { execute("git pull") }
    else
      debug "Cloning dotfiles repository..."
      execute("git clone #{@dotfiles_repo} #{@dotfiles_dir}")
    end
  end

  def complete?
    @system.dir_exist?(@dotfiles_dir) && @system.dir_exist?(File.join(@dotfiles_dir, ".git"))
  end
end
