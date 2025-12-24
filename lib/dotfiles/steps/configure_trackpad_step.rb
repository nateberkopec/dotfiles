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

  def trackpad_settings
    @config.fetch("trackpad_settings", {})
  end

  def setting_entries
    trackpad_settings.flat_map do |domain, settings|
      settings.map { |key, value| [domain, key, value] }
    end
  end
end
