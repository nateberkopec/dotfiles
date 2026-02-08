class Dotfiles::Step::ConfigureTrackpadStep < Dotfiles::Step
  include Dotfiles::Step::DefaultsConfigurable

  defaults_config_key "trackpad_settings"
  defaults_display_name "Trackpad"
end
