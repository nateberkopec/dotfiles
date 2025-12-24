require "date"

class Dotfiles::Step::UpdateMacOSStep < Dotfiles::Step
  macos_only

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
    output = read_software_update_plist("RecommendedUpdates")
    return [] unless output
    parse_minor_updates(output)
  end

  def read_software_update_plist(key)
    plist_path = "/Library/Preferences/com.apple.SoftwareUpdate.plist"
    return nil unless @system.file_exist?(plist_path)
    output, status = @system.execute("defaults read #{plist_path} #{key} 2>/dev/null")
    (status == 0) ? output : nil
  end

  def parse_minor_updates(output)
    updates = output.lines.filter_map { |line| extract_minor_update_id(line) }
    debug "Minor macOS updates available: #{updates.join(", ")}" unless updates.empty?
    updates
  end

  def extract_minor_update_id(line)
    line.match(/Identifier = "(MSU_UPDATE_[^"]+_minor)"/)&.[](1)
  end

  def check_background_update_freshness
    output = read_software_update_plist("LastBackgroundSuccessfulDate")
    return unless output
    warn_if_stale(parse_last_check_date(output))
  end

  def parse_last_check_date(output)
    DateTime.parse(output.strip)
  rescue
    nil
  end

  def warn_if_stale(last_check)
    return unless last_check
    hours = ((DateTime.now - last_check) * 24).to_i
    return unless hours > 24
    add_warning(title: "⚠️  macOS Update Check Stale", message: "Last background update check was #{hours} hours ago.\nConsider checking System Settings > General > Software Update.")
  end
end
