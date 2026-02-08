class Dotfiles::Step::ConfigureDockStep < Dotfiles::Step
  macos_only
  include Dotfiles::Step::Defaultable

  def self.depends_on
    [Dotfiles::Step::CreateStandardFoldersStep]
  end

  def run
    run_defaults_write
    configure_dock_items
    execute("killall Dock")
  end

  def complete?
    super
    defaults_complete?("Dock")
    check_dock_items
    @errors.empty?
  end

  private

  def config_key
    "dock_settings"
  end

  def configure_dock_items
    execute("defaults write com.apple.dock persistent-apps -array")
    execute("defaults delete com.apple.dock persistent-others 2>/dev/null || true")
    execute("defaults write com.apple.dock persistent-others -array-add '#{inbox_tile_data}'")
  end

  def inbox_tile_data
    "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>file://#{inbox_path}/</string><key>_CFURLStringType</key><integer>15</integer></dict></dict></dict>"
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
