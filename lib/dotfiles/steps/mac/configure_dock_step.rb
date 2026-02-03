class Dotfiles::Step::ConfigureDockStep < Dotfiles::Step
  macos_only
  include Dotfiles::Step::Defaultable

  def self.depends_on
    [Dotfiles::Step::CreateStandardFoldersStep]
  end

  def run
    configure_dock_behavior
    configure_dock_items
    execute("killall Dock")
  end

  def complete?
    super
    check_dock_settings
    check_dock_items
    @errors.empty?
  end

  private

  def configure_dock_behavior
    execute("defaults write com.apple.dock autohide -bool true")
    execute("defaults write com.apple.dock orientation left")
    execute("defaults write com.apple.dock autohide-delay -float 0")
    execute("defaults write com.apple.dock autohide-time-modifier -float 0.4")
  end

  def configure_dock_items
    execute("defaults write com.apple.dock persistent-apps -array")
    execute("defaults delete com.apple.dock persistent-others 2>/dev/null || true")
    execute("defaults write com.apple.dock persistent-others -array-add '#{inbox_tile_data}'")
  end

  def inbox_tile_data
    "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>file://#{inbox_path}/</string><key>_CFURLStringType</key><integer>15</integer></dict></dict></dict>"
  end

  def check_dock_settings
    add_error("Dock autohide not set to true") unless defaults_read_equals?(build_read_command("com.apple.dock", "autohide"), "1")
    add_error("Dock orientation not set to left") unless defaults_read_equals?(build_read_command("com.apple.dock", "orientation"), "left")
    add_error("Dock autohide-delay not set to 0") unless defaults_read_equals?(build_read_command("com.apple.dock", "autohide-delay"), "0")
    add_error("Dock autohide-time-modifier not set to 0.4") unless defaults_read_equals?(build_read_command("com.apple.dock", "autohide-time-modifier"), "0.4")
  end

  def check_dock_items
    add_error("Dock persistent-apps is not empty") unless persistent_apps_empty?
    add_error("Inbox folder not in Dock persistent-others") unless inbox_in_persistent_others?
  end

  def inbox_path
    File.join(@home, "Documents", "Inbox")
  end

  def persistent_apps_empty?
    output, status = execute("defaults read com.apple.dock persistent-apps", quiet: true)
    status == 0 && output.strip == "(\n)"
  end

  def inbox_in_persistent_others?
    output, status = execute("defaults read com.apple.dock persistent-others", quiet: true)
    status == 0 && output.include?(inbox_path)
  end
end
