require "json"

# Casks stay with real Homebrew: mise's cask backend can't recognize casks
# brew installed and can't install tapped casks without API metadata. On
# non-admin machines this step also installs the [bootstrap.packages] brew
# formulae, since `dotf run` skips the mise packages phase there (mise's
# native brew backend can't target the private ~/.homebrew prefix).
class Dotfiles::Step::InstallBrewCasksStep < Dotfiles::Step
  DESCRIPTION = "Installs Homebrew casks, plus formulae on non-admin machines.".freeze

  macos_only

  def initialize(**kwargs)
    super
    @brewfile_path = temp_path("brewfile")
    @packages_installed_status = nil
  end

  def should_run?
    return false unless brewfile_needed?

    generate_brewfile
    !packages_already_installed?
  end

  def run
    debug "Installing Homebrew casks..."
    update_homebrew
    install_and_reset
    install_and_reset unless packages_already_installed?
  end

  def complete?
    super
    return true unless brewfile_needed?

    generate_brewfile
    add_missing_packages_error unless packages_already_installed?
    @packages_installed_status
  end

  private

  def update_homebrew
    brew_quiet("update")
  end

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
    debug "All Homebrew casks are installed" if @packages_installed_status
    @packages_installed_status
  end

  def reset_package_status
    @packages_installed_status = nil
    @packages_installed_error = nil
  end

  def add_missing_packages_error
    message = "Some Homebrew casks are not installed"
    details = @packages_installed_error.to_s.strip
    message = "#{message}: #{details}" unless details.empty?
    add_error(message)
  end

  def install_packages
    @system.execute(env_command({"HOMEBREW_NO_AUTO_UPDATE" => "1", "HOMEBREW_NO_ENV_HINTS" => "1", "HOMEBREW_CASK_OPTS" => cask_opts}, "brew", "bundle", "install", "--file=#{@brewfile_path}"))
  end

  def cask_opts
    user_has_admin_rights? ? "" : "--appdir=~/Applications"
  end

  def log_installation_results(output, exit_status)
    return if exit_status == 0

    debug "brew bundle install exited with status #{exit_status}"
    debug "Output:\n#{output}" if @debug
  end

  def generate_brewfile
    @system.write_file(@brewfile_path, brewfile_content)
  end

  def brewfile_content
    [
      *formulae.map { |pkg| "brew \"#{pkg}\"" },
      *casks.map { |cask| "cask \"#{cask}\"" }
    ].join("\n") + "\n"
  end

  def brewfile_needed?
    formulae.any? || casks.any?
  end

  def casks
    @config.brew_casks
  end

  def formulae
    return [] if user_has_admin_rights?

    declared_mise_brew_formulae
  end

  def declared_mise_brew_formulae
    @declared_mise_brew_formulae ||= fetch_declared_mise_brew_formulae
  end

  def fetch_declared_mise_brew_formulae
    output, status = execute(command("mise", "-C", @home, "bootstrap", "packages", "status", "--json"))
    return [] unless status == 0

    JSON.parse(output).fetch("brew", {}).fetch("packages", []).map { |package| package["package"] }
  rescue JSON::ParserError
    []
  end
end
