class UpdateHomebrewStep < Step
  def run
    debug 'Updating Homebrew package definitions...'
    brew_quiet('update')
  end

  def complete?
    true
  end
end