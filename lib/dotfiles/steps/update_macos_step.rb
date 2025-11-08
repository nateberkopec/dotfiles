class Dotfiles::Step::UpdateMacOSStep < Dotfiles::Step
  def self.display_name
    "Update macOS"
  end

  def should_run?
    user_has_admin_rights? && !ci_or_noninteractive? && minor_updates_available.any?
  end

  def run
    updates = minor_updates_available
    update_list = updates.map { |id| "  • #{id}" }.join("\n")

    add_notice(
      title: "macOS Updates Available",
      message: "The following macOS updates are available:\n#{update_list}\n\nTo install updates:\n  • Open System Settings → General → Software Update\n  • Or run: sudo softwareupdate -i --recommended"
    )
  end

  def complete?
    super
    return true if ci_or_noninteractive?

    check_background_update_freshness
    updates = minor_updates_available
    updates.each { |update| add_error("macOS update available: #{update}") }
    updates.empty?
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
