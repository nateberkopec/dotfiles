class Dotfiles::Step::ConfigureScreenshotsStep < Dotfiles::Step::DefaultsStep
  defaults_config_key "screenshot_settings"
  defaults_display_name "Screenshot"

  def self.depends_on
    [Dotfiles::Step::CreateStandardFoldersStep]
  end

  private

  def after_defaults_write
    execute("killall SystemUIServer")
  end
end
