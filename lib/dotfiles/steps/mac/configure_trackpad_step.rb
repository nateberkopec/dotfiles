class Dotfiles::Step::ConfigureTrackpadStep < Dotfiles::Step
  DESCRIPTION = "Applies preferred macOS trackpad settings.".freeze

  include Dotfiles::Step::DefaultsConfigurable

  defaults_config_key "trackpad_settings"
  defaults_display_name "Trackpad"
end
