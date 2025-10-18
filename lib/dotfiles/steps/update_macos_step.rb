class Dotfiles::Step::UpdateMacOSStep < Dotfiles::Step
  def self.display_name
    "Update macOS"
  end

  def should_run?
    user_has_admin_rights? && !ci_or_noninteractive? && !complete?
  end

  def run
    debug "User has admin rights, checking for macOS updates..."
    execute("softwareupdate -i -a", sudo: true, quiet: true)
  end

  def complete?
    output = execute("softwareupdate -l --no-scan", capture_output: true, quiet: true)
    !output.include?("No new software available.")
  rescue
    false
  end

  private

  def user_has_admin_rights?
    groups = `groups`.strip
    groups.include?("admin")
  end
end
