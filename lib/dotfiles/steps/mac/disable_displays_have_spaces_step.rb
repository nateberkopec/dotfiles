class Dotfiles::Step::DisableDisplaysHaveSpacesStep < Dotfiles::Step
  DESCRIPTION = "Configures macOS Spaces to span across multiple displays.".freeze

  macos_only
  include Dotfiles::Step::Defaultable

  def run
    debug "Configuring Spaces to span across multiple displays..."
    execute(command("defaults", "write", "com.apple.spaces", "spans-displays", "-bool", "true"))
    execute(command("killall", "SystemUIServer"))
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
