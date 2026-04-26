class Dotfiles::Step::UpdateHomebrewStep < Dotfiles::Step
  DESCRIPTION = "Updates Homebrew package definitions before package installation runs.".freeze

  macos_only

  def run
    debug "Updating Homebrew package definitions..."
    brew_quiet("update")
  end

  def complete?
    super
    true
  end
end
