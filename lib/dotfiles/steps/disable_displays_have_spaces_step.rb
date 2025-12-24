class Dotfiles::Step::DisableDisplaysHaveSpacesStep < Dotfiles::Step
  macos_only
  include Dotfiles::Step::Defaultable

  def run
    debug "Configuring Spaces to span across multiple displays..."
    execute("defaults write com.apple.spaces spans-displays -bool true && killall SystemUIServer")
  end

  def complete?
    super
    defaults_complete?("Displays-have-spaces")
  end

  private

  def setting_entries
    [["com.apple.spaces", "spans-displays", "1"]]
  end
end
