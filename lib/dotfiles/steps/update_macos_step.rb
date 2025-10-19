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
    output, status = execute("softwareupdate -l --no-scan", quiet: true)
    return false unless status == 0
    !output.include?("No new software available.")
  end

  private

  def user_has_admin_rights?
    groups, = @system.execute("groups")
    groups.include?("admin")
  end
end
