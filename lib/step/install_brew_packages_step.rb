class InstallBrewPackagesStep < Step
  def self.depends_on
    [InstallHomebrewStep]
  end

  def run
    debug "Installing command-line tools via Homebrew..."

    packages = @config.packages["brew"]["packages"]
    brew_quiet("install #{packages.join(" ")}")

    cask_packages = @config.packages["brew"]["casks"]
    brew_quiet("install --cask #{cask_packages.join(" ")}")
  end

  def complete?
    packages = @config.packages["brew"]["packages"]
    cask_packages = @config.packages["brew"]["casks"]

    installed_packages = execute("brew list --formula", capture_output: true, quiet: true).split("\n")
    installed_casks = execute("brew list --cask", capture_output: true, quiet: true).split("\n")

    packages_installed = packages.all? { |pkg| installed_packages.include?(pkg) }
    cask_apps_installed = cask_packages.all? do |cask|
      cask_name = cask.split("/").last
      installed_casks.include?(cask_name)
    end

    packages_installed && cask_apps_installed
  rescue
    false
  end

  # Export currently installed brew formulae and casks back into the repo
  # for reference and future installs.
  def update
    return unless command_exists?("brew")

    dest_dir = File.join(@dotfiles_dir, "files", "brew")
    FileUtils.mkdir_p(dest_dir)

    begin
      formulae = execute("brew list --formula", capture_output: true, quiet: true)
      File.write(File.join(dest_dir, "formulae.txt"), formulae.strip + "\n")
    rescue => e
      debug "Failed to export brew formulae: #{e.message}"
    end

    begin
      casks = execute("brew list --cask", capture_output: true, quiet: true)
      File.write(File.join(dest_dir, "casks.txt"), casks.strip + "\n")
    rescue => e
      debug "Failed to export brew casks: #{e.message}"
    end
  end
end
