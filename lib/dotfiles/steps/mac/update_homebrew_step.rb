class Dotfiles::Step::UpdateHomebrewStep < Dotfiles::Step
  DESCRIPTION = "Runs Homebrew's auto-update check before package installation.".freeze

  macos_only

  def run
    debug "Checking whether Homebrew package definitions need updating..."
    brew_quiet("update-if-needed")
  end

  def complete?
    super
    true
  end
end
