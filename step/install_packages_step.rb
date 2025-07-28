class InstallPackagesStep < Step
  def run
    debug 'Installing command-line tools and applications via Homebrew...'

    packages = %w[zoxide ghostty bat gh rust mise direnv fish orbstack fontconfig libyaml coreutils]
    brew_quiet("install #{packages.join(' ')}")

    cask_packages = %w[nikitabobko/tap/aerospace github visual-studio-code raycast keycastr]
    brew_quiet("install --cask #{cask_packages.join(' ')}")

    install_1password
    install_arc_browser
  end

  def complete?
    packages = %w[zoxide bat gh rust mise direnv fish fontconfig libyaml coreutils]
    cask_packages = %w[nikitabobko/tap/aerospace github visual-studio-code raycast keycastr ghostty orbstack]

    installed_packages = execute('brew list --formula', capture_output: true, quiet: true).split("\n")
    installed_casks = execute('brew list --cask', capture_output: true, quiet: true).split("\n")

    packages_installed = packages.all? { |pkg| installed_packages.include?(pkg) }
    cask_apps_installed = cask_packages.all? do |cask|
      cask_name = cask.split('/').last
      installed_casks.include?(cask_name)
    end

    onepass_installed = Dir.exist?('/Applications/1Password.app')
    arc_installed = Dir.exist?('/Applications/Arc.app')

    packages_installed && cask_apps_installed && onepass_installed && arc_installed
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