class Dotfiles::Step::DisableAirplayReceiverStep < Dotfiles::Step
  DESCRIPTION = "Disables the AirPlay Receiver so Control Center stops listening on ports 5000 and 7000.".freeze

  macos_only
  include Dotfiles::Step::Defaultable

  def run
    execute(command("defaults", "-currentHost", "write", "com.apple.controlcenter", "AirplayReceiverEnabled", "-bool", "false"))
    execute(command("killall", "ControlCenter"))
  end

  def complete?
    super
    defaults_complete?("AirPlay Receiver", current_host: true)
  end

  private

  def setting_entries
    [["com.apple.controlcenter", "AirplayReceiverEnabled", "0"]]
  end
end
