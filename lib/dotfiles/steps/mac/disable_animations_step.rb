class Dotfiles::Step::DisableAnimationsStep < Dotfiles::Step
  macos_only
  include Dotfiles::Step::Defaultable

  def run
    run_defaults_write
    execute("killall Dock")
    execute("killall Finder")
  end

  def complete?
    super
    defaults_complete?("Animation")
  end

  def update
    update_defaults_config("animation_settings")
  end

  private

  def config_key
    "animation_settings"
  end
end
