class Dotfiles::Step::DisableDisplaysHaveSpacesStep < Dotfiles::Step
  include Dotfiles::Step::Defaultable

  def run
    debug "Configuring Spaces to span across multiple displays..."
    execute("defaults write com.apple.spaces spans-displays -bool true && killall SystemUIServer")
  end

  def complete?
    defaults_read_equals?(build_read_command("com.apple.spaces", "spans-displays"), "1")
  end
end
