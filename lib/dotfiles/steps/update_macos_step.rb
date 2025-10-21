class Dotfiles::Step::UpdateMacOSStep < Dotfiles::Step
  def self.display_name
    "Update macOS"
  end

  def should_run?
    user_has_admin_rights? && !ci_or_noninteractive? && minor_updates_available.any?
  end

  def run
    debug "User has admin rights, checking for macOS updates..."
    execute("softwareupdate -i --recommended", sudo: true, quiet: true)
  end

  def complete?
    check_background_update_freshness
    minor_updates_available.empty?
  end

  private

  def minor_updates_available
    plist_path = "/Library/Preferences/com.apple.SoftwareUpdate.plist"
    return [] unless @system.file_exist?(plist_path)

    output, status = @system.execute("defaults read #{plist_path} RecommendedUpdates 2>/dev/null")
    return [] unless status == 0

    updates = output.lines.select { |line| line.match?(/Identifier = ".*_minor"/) }.map do |line|
      line.match(/Identifier = "(MSU_UPDATE_[^"]+_minor)"/)[1]
    rescue
      nil
    end.compact
    debug "Minor macOS updates available: #{updates.join(", ")}" unless updates.empty?
    updates
  end

  def check_background_update_freshness
    plist_path = "/Library/Preferences/com.apple.SoftwareUpdate.plist"
    return unless @system.file_exist?(plist_path)

    output, status = @system.execute("defaults read #{plist_path} LastBackgroundSuccessfulDate 2>/dev/null")
    return unless status == 0

    last_check = begin
      DateTime.parse(output.strip)
    rescue
      nil
    end
    return unless last_check

    hours_since_check = ((DateTime.now - last_check) * 24).to_i
    if hours_since_check > 24
      add_warning(
        title: "⚠️  macOS Update Check Stale",
        message: "Last background update check was #{hours_since_check} hours ago.\nConsider checking System Settings > General > Software Update."
      )
    end
  end

  def user_has_admin_rights?
    groups, = @system.execute("groups")
    groups.include?("admin")
  end
end
