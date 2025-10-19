class Dotfiles::Step::InstallBrewPackagesStep < Dotfiles::Step
  def self.depends_on
    [Dotfiles::Step::InstallHomebrewStep]
  end

  def initialize(**kwargs)
    super
    @brewfile_path = File.join(@dotfiles_dir, "Brewfile")
  end

  def run
    debug "Installing command-line tools via Homebrew..."
    generate_brewfile
    return if packages_already_installed?

    output, exit_status = install_packages
    check_skipped_packages
    log_installation_results(output, exit_status)
  end

  def packages_already_installed?
    _, status = @system.execute("brew bundle check --file=#{@brewfile_path} --no-upgrade >/dev/null 2>&1")
    result = status == 0
    debug "All packages already installed" if result
    result
  end

  def install_packages
    cask_opts = user_has_admin_rights? ? "" : "--appdir=~/Applications"
    @system.execute("HOMEBREW_CASK_OPTS=\"#{cask_opts}\" brew bundle install --file=#{@brewfile_path} 2>&1")
  end

  def check_skipped_packages
    packages = @config.packages["brew"]["packages"]
    casks = @config.packages["brew"]["casks"]
    installed_formulae, = @system.execute("brew list --formula 2>/dev/null")
    installed_casks, = @system.execute("brew list --cask 2>/dev/null")
    installed_formulae = installed_formulae.split("\n")
    installed_casks = installed_casks.split("\n")

    skipped_packages = packages.reject { |pkg| installed_formulae.include?(pkg) }
    skipped_casks = casks.reject { |cask| installed_casks.include?(cask) }

    if skipped_packages.any? || skipped_casks.any?
      warning_lines = ["No admin rights detected."]
      warning_lines << "\nSkipped formulae:" if skipped_packages.any?
      warning_lines.concat(skipped_packages.map { |pkg| "• #{pkg}" })
      warning_lines << "\nSkipped casks:" if skipped_casks.any?
      warning_lines.concat(skipped_casks.map { |cask| "• #{cask}" })

      add_warning(
        title: "⚠️  Homebrew Installation Skipped",
        message: warning_lines.join("\n")
      )
    end
  end

  def log_installation_results(output, exit_status)
    return if exit_status == 0

    debug "brew bundle install exited with status #{exit_status}"
    debug "Output:\n#{output}" if @debug
  end

  def complete?
    return true if ran?
    return false unless @system.file_exist?(@brewfile_path)
    _, status = @system.execute("brew bundle check --file=#{@brewfile_path} --no-upgrade >/dev/null 2>&1")
    status == 0
  end

  def update
  end

  private

  def generate_brewfile
    packages = @config.packages["brew"]["packages"]
    cask_packages = @config.packages["brew"]["casks"]

    brewfile_content = []
    packages.each { |pkg| brewfile_content << "brew \"#{pkg}\"" }
    cask_packages.each { |cask| brewfile_content << "cask \"#{cask}\"" }

    @system.write_file(@brewfile_path, brewfile_content.join("\n") + "\n")
  end
end
