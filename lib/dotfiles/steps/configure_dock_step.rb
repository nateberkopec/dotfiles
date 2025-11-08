class Dotfiles::Step::ConfigureDockStep < Dotfiles::Step
  def run
    inbox_path = File.join(@home, "Documents", "Inbox")
    @system.mkdir_p(inbox_path)

    execute("defaults write com.apple.dock autohide -bool true")
    execute("defaults write com.apple.dock orientation left")
    execute("defaults write com.apple.dock persistent-apps -array")
    execute("defaults write com.apple.dock autohide-delay -float 0")
    execute("defaults write com.apple.dock autohide-time-modifier -float 0.4")

    execute("defaults delete com.apple.dock persistent-others 2>/dev/null || true")

    tile_data = "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>file://#{inbox_path}/</string><key>_CFURLStringType</key><integer>15</integer></dict></dict></dict>"
    execute("defaults write com.apple.dock persistent-others -array-add '#{tile_data}'")

    execute("killall Dock")
  end

  def complete?
    defaults_read_equals?("defaults read com.apple.dock autohide", "1") &&
      defaults_read_equals?("defaults read com.apple.dock orientation", "left") &&
      defaults_read_equals?("defaults read com.apple.dock autohide-delay", "0") &&
      defaults_read_equals?("defaults read com.apple.dock autohide-time-modifier", "0.4") &&
      persistent_apps_empty? &&
      inbox_in_persistent_others?
  end

  private

  def persistent_apps_empty?
    output, status = execute("defaults read com.apple.dock persistent-apps", quiet: true)
    return false unless status == 0
    output.strip == "(\n)"
  end

  def inbox_in_persistent_others?
    inbox_path = File.join(@home, "Documents", "Inbox")
    output, status = execute("defaults read com.apple.dock persistent-others", quiet: true)
    return false unless status == 0
    output.include?(inbox_path)
  end
end
