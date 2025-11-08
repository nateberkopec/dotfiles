class Dotfiles::Step::UpdateHomebrewStep < Dotfiles::Step
  def self.depends_on
    [Dotfiles::Step::InstallHomebrewStep]
  end

  def run
    debug "Updating Homebrew package definitions..."
    brew_quiet("update")
  end

  def complete?
    super
    true
  end
end
