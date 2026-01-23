class Dotfiles::Step::SetFishDefaultShellStep < Dotfiles::Step
  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep]
  end

  def run
    debug "Setting Fish as the default shell..."
    add_fish_to_shells unless fish_in_shells?
    change_default_shell
  end

  def add_fish_to_shells
    debug "Adding Fish to allowed shells..."
    return debug("Skipping adding Fish to /etc/shells in CI (requires sudo)") if ci_or_noninteractive?
    _, status = execute("bash -lc 'echo #{fish_path} >> /etc/shells'", sudo: true)
    add_error("Failed to add Fish to /etc/shells") unless status == 0
  end

  def change_default_shell
    debug "Changing default shell to Fish..."
    return debug("Skipping chsh in CI (would require user password)") if ci_or_noninteractive?
    execute("chsh -s #{fish_path}")
  end

  def complete?
    super
    return true if ci_or_noninteractive?
    add_error("Fish is not set as the default shell (current: #{current_shell.strip})") unless fish_is_default?
    @errors.empty?
  end

  private

  def fish_path
    @fish_path ||= @system.execute("which fish").first
  end

  def fish_in_shells?
    @system.readlines("/etc/shells").any? { |line| line.strip == fish_path }
  end

  def current_shell
    execute("dscl . -read ~/ UserShell", quiet: true).first
  end

  def fish_is_default?
    current_shell.include?(fish_path)
  end
end
