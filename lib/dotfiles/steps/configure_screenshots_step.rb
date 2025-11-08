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
    setting_entries.all? do |domain, key, expected_value|
      defaults_read_equals?(build_read_command(domain, key), expected_value)
    end
  end

  def update
    update_defaults_config("screenshot_settings", "screenshots.yml")
  end

  private

  def screenshot_settings
    @config.load_config("screenshots.yml").fetch("screenshot_settings", {})
  end

  def setting_entries
    screenshot_settings.flat_map do |domain, settings|
      settings.map { |key, value| [domain, key, value] }
    end
  end
end
