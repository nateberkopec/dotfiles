class CloneDotfilesStep < Step
  def run
    if Dir.exist?(@dotfiles_dir)
      debug 'Dotfiles directory already exists, pulling latest changes...'
      Dir.chdir(@dotfiles_dir) { execute('git pull') }
    else
      debug 'Cloning dotfiles repository...'
      execute("git clone #{@dotfiles_repo} #{@dotfiles_dir}")
    end
  end

  def complete?
    Dir.exist?(@dotfiles_dir) && Dir.exist?(File.join(@dotfiles_dir, '.git'))
  end
end