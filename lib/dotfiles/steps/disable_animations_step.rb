class Dotfiles::Step::DisableAnimationsStep < Dotfiles::Step
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
    update_defaults_config("animation_settings", "animations.yml")
  end

  private

  def animation_settings
    @config.load_config("animations.yml").fetch("animation_settings", {})
  end

  def setting_entries
    animation_settings.flat_map do |domain, settings|
      settings.map { |key, value| [domain, key, value] }
    end
  end
end
