class Dotfiles::Step::SetFishDefaultShellStep < Dotfiles::Step
  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep]
  end

  def run
    debug "Setting Fish as the default shell..."
    fish_path, = @system.execute("which fish")

    unless @system.readlines("/etc/shells").any? { |line| line.strip == fish_path }
      debug "Adding Fish to allowed shells..."
      if ci_or_noninteractive?
        debug "Skipping adding Fish to /etc/shells in CI (requires sudo)"
      else
        execute("bash -lc 'echo #{fish_path} >> /etc/shells'", sudo: true)
      end
    end

    debug "Changing default shell to Fish..."
    if ci_or_noninteractive?
      debug "Skipping chsh in CI (would require user password)"
    else
      execute("chsh -s #{fish_path}")
    end
  end

  def complete?
    super
    return true if ci_or_noninteractive?

    fish_path, = @system.execute("which fish")
    current_shell, = execute("dscl . -read ~/ UserShell", quiet: true)

    unless current_shell.include?(fish_path)
      add_error("Fish is not set as the default shell (current: #{current_shell.strip})")
      return false
    end

    true
  end
end
