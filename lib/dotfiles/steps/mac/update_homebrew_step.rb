class Dotfiles::Step::UpdateHomebrewStep < Dotfiles::Step
  DESCRIPTION = "Lets Homebrew auto-update package definitions when its throttle allows.".freeze

  macos_only

  def run
    debug "Checking whether Homebrew package definitions need an auto-update..."
    brew_quiet("update-if-needed")
  end

  def complete?
    super
    true
  end
end
