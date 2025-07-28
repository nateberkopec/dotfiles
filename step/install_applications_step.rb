class InstallApplicationsStep < Step
  def run
    debug 'Installing applications...'
    install_1password
    install_arc_browser
  end

  def complete?
    onepass_installed = Dir.exist?('/Applications/1Password.app')
    arc_installed = Dir.exist?('/Applications/Arc.app')

    onepass_installed && arc_installed
  rescue
    false
  end

  private

  def install_1password
    unless Dir.exist?('/Applications/1Password.app')
      debug 'Installing 1Password...'
      brew_quiet('install --cask 1password 1password/tap/1password-cli')
    else
      debug '1Password is already installed, skipping...'
    end
  end

  def install_arc_browser
    unless Dir.exist?('/Applications/Arc.app')
      debug 'Installing Arc browser...'
      brew_quiet('install --cask arc')
    else
      debug 'Arc browser is already installed, skipping...'
    end
  end
end