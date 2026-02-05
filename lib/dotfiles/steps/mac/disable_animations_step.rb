class Dotfiles::Step::DisableAnimationsStep < Dotfiles::Step::DefaultsStep
  defaults_config_key "animation_settings"
  defaults_display_name "Animation"

  private

  def after_defaults_write
    execute("killall Dock")
    execute("killall Finder")
  end
end
