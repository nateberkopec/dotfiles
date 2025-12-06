class Dotfiles::Step::ConfigureScreenshotsStep < Dotfiles::Step
  include Dotfiles::Step::Defaultable

  def self.depends_on
    [Dotfiles::Step::CreateStandardFoldersStep]
  end

  def run
    run_defaults_write
    execute("killall SystemUIServer")
  end

  def complete?
    super
    defaults_complete?("Screenshot")
  end

  def update
    update_defaults_config("screenshot_settings")
  end

  private

  def screenshot_settings
    @config.fetch("screenshot_settings", {})
  end

  def setting_entries
    screenshot_settings.flat_map do |domain, settings|
      settings.map { |key, value| [domain, key, value] }
    end
  end
end
