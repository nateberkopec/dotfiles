class Dotfiles::Step::SetFontSmoothingStep < Dotfiles::Step
  DESCRIPTION = "Disables macOS font smoothing for preferred text rendering.".freeze

  macos_only
  include Dotfiles::Step::Defaultable

  def run
    debug "Disabling font smoothing for better text rendering..."
    execute("defaults -currentHost write -g AppleFontSmoothing -int 0")
  end

  def complete?
    super
    defaults_complete?("Font smoothing", current_host: true)
  end

  private

  def setting_entries
    [["NSGlobalDomain", "AppleFontSmoothing", "0"]]
  end
end
