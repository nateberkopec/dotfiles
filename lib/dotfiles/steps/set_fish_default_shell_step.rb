class Dotfiles::Step::SetFishDefaultShellStep < Dotfiles::Step
  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep]
  end

  def run
    debug "Setting Fish as the default shell..."
    fish_path, = @system.execute("which fish")

    unless File.readlines("/etc/shells").any? { |line| line.strip == fish_path }
      debug "Adding Fish to allowed shells..."
      execute("echo #{fish_path} | sudo tee -a /etc/shells", sudo: true)
    end

    debug "Changing default shell to Fish..."
    execute("chsh -s #{fish_path}")
  end

  def complete?
    return true if ci_or_noninteractive?
    fish_path, = @system.execute("which fish")
    current_shell, = execute("dscl . -read ~/ UserShell", quiet: true)
    current_shell.include?(fish_path)
  end
end
