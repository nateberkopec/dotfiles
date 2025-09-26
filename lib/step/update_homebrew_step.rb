class UpdateHomebrewStep < Step
  def self.depends_on
    [InstallHomebrewStep]
  end

  def run
    debug "Updating Homebrew package definitions..."
    brew_quiet("update")
  end

  def complete?
    true
  end
end
