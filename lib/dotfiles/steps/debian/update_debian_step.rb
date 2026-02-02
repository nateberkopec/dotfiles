class Dotfiles::Step::UpdateDebianStep < Dotfiles::Step
  debian_only

  def self.display_name
    "Update Debian/Ubuntu"
  end

  def should_run?
    release_updates_available.any?
  end

  def run
    updates = release_updates_available
    return if updates.empty?

    update_list = updates.map { |release| "  • #{release}" }.join("\n")
    add_notice(
      title: "Debian/Ubuntu Release Updates Available",
      message: "The following release upgrades are available:\n#{update_list}\n\nTo check:\n  • Run: do-release-upgrade -c\nTo upgrade:\n  • Run: do-release-upgrade"
    )
  end

  def complete?
    super
    return true if ci_or_noninteractive?
    release_updates_available.each { |release| add_error("Release upgrade available: #{release}") }
    release_updates_available.empty?
  end

  private

  def release_updates_available
    return [] unless command_exists?("do-release-upgrade")
    output, status = execute("do-release-upgrade -c", quiet: true)
    return [] unless status == 0
    output.scan(/New release '([^']+)'/).flatten
  end

  def ci_or_noninteractive?
    ENV["CI"] || ENV["NONINTERACTIVE"]
  end
end
