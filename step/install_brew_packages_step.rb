class InstallBrewPackagesStep < Step
  def run
    debug 'Installing command-line tools via Homebrew...'

    packages = @config.packages['brew']['packages']
    brew_quiet("install #{packages.join(' ')}")

    cask_packages = @config.packages['brew']['casks']
    brew_quiet("install --cask #{cask_packages.join(' ')}")
  end

  def complete?
    packages = @config.packages['brew']['packages']
    cask_packages = @config.packages['brew']['casks']

    installed_packages = execute('brew list --formula', capture_output: true, quiet: true).split("\n")
    installed_casks = execute('brew list --cask', capture_output: true, quiet: true).split("\n")

    packages_installed = packages.all? { |pkg| installed_packages.include?(pkg) }
    cask_apps_installed = cask_packages.all? do |cask|
      cask_name = cask.split('/').last
      installed_casks.include?(cask_name)
    end

    packages_installed && cask_apps_installed
  rescue
    false
  end
end