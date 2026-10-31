class Dotfiles::Step::DisableFirewallSignedAutoAllowStep < Dotfiles::Step
  DESCRIPTION = "Stops the macOS firewall from automatically allowing signed software to accept incoming connections.".freeze

  prepend Dotfiles::Step::Sudoable

  macos_only

  def run
    _, status = execute(command(socketfilterfw, "--setallowsigned", "off", "--setallowsignedapp", "off"), sudo: true)
    add_error("Failed to disable firewall signed-software auto-allow") unless status == 0
  end

  def complete?
    super
    output, status = execute(command(socketfilterfw, "--getallowsigned"))
    add_error("Firewall still automatically allows signed software") unless status == 0 && !output.include?("ENABLED")
    @errors.empty?
  end

  private

  def socketfilterfw
    "/usr/libexec/ApplicationFirewall/socketfilterfw"
  end
end
