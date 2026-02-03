class Dotfiles::Step::ConfigureScreenshotsStep < Dotfiles::Step
  macos_only
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

  def config_key
    "screenshot_settings"
  end
end
