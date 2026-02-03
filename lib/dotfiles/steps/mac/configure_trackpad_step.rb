class Dotfiles::Step::ConfigureTrackpadStep < Dotfiles::Step
  macos_only
  include Dotfiles::Step::Defaultable

  def run
    run_defaults_write
  end

  def complete?
    super
    defaults_complete?("Trackpad")
  end

  def update
    update_defaults_config("trackpad_settings")
  end

  private

  def config_key
    "trackpad_settings"
  end
end
