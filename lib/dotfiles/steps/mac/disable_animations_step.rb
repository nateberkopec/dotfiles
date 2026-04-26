class Dotfiles::Step::DisableAnimationsStep < Dotfiles::Step
  DESCRIPTION = "Disables selected macOS animations for a faster-feeling interface.".freeze

  include Dotfiles::Step::DefaultsConfigurable

  defaults_config_key "animation_settings"
  defaults_display_name "Animation"

  private

  def after_defaults_write
    execute(command("killall", "Dock"))
    execute(command("killall", "Finder"))
  end
end
