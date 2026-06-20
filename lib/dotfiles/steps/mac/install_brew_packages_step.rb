class Dotfiles::Step::InstallBrewPackagesStep < Dotfiles::Step
  DESCRIPTION = "Installs Homebrew-managed apps and non-admin formulae.".freeze

  macos_only

  def self.depends_on
    [Dotfiles::Step::UpdateHomebrewStep]
  end

  def initialize(**kwargs)
    super
    @brewfile_path = File.join(@dotfiles_dir, "Brewfile")
    @packages_installed_status = nil
  end

  def should_run?
    return false unless brewfile_needed?

    generate_brewfile
    !packages_already_installed?
  end

  def run
    debug "Installing Homebrew-managed apps..."
    install_and_reset
    install_and_reset unless packages_already_installed?
  end

  def complete?
    super
    return true unless brewfile_needed?

    add_missing_packages_error unless packages_already_installed?
    @packages_installed_status
  end

  private

  def install_and_reset
    output, exit_status = install_packages
    log_installation_results(output, exit_status)
    reset_package_status
  end

  def packages_already_installed?
    return @packages_installed_status unless @packages_installed_status.nil?

    output, status = brew_quiet("bundle", "check", "--file=#{@brewfile_path}", "--no-upgrade")
    @packages_installed_status = status == 0
    @packages_installed_error = output unless @packages_installed_status
    debug "All Homebrew-managed apps are installed" if @packages_installed_status
    @packages_installed_status
  end

  def reset_package_status
    @packages_installed_status = nil
    @packages_installed_error = nil
  end

  def add_missing_packages_error
    message = "Some Homebrew-managed apps are not installed"
    details = @packages_installed_error.to_s.strip
    message = "#{message}: #{details}" unless details.empty?
    add_error(message)
  end

  def install_packages
    @system.execute(env_command({"HOMEBREW_NO_AUTO_UPDATE" => "1", "HOMEBREW_NO_ENV_HINTS" => "1", "HOMEBREW_CASK_OPTS" => cask_opts}, "brew", "bundle", "install", "--file=#{@brewfile_path}"))
  end

  def log_installation_results(output, exit_status)
    return if exit_status == 0

    debug "brew bundle install exited with status #{exit_status}"
    debug "Output:\n#{output}" if @debug
  end

  def generate_brewfile
    @system.write_file(@brewfile_path, build_brewfile_content(brew_config))
  end

  def build_brewfile_content(config)
    [
      *(config["taps"] || []).map { |tap| "tap \"#{tap}\"" },
      *formulae_for_brewfile(config).map { |pkg| "brew \"#{pkg}\"" },
      *(config["casks"] || []).map { |cask| "cask \"#{cask}\"" }
    ].join("\n") + "\n"
  end

  def brewfile_needed?
    (brew_config["taps"] || []).any? || (brew_config["casks"] || []).any? || formulae_for_brewfile(brew_config).any?
  end

  def formulae_for_brewfile(config)
    user_has_admin_rights? ? [] : (config["packages"] || [])
  end

  def brew_config
    @config.packages&.dig("brew") || {}
  end

  def cask_opts
    user_has_admin_rights? ? "" : "--appdir=~/Applications"
  end
end
