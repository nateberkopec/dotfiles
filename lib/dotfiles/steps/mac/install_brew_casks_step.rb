require "json"

# Mise cannot target the private Homebrew prefix used by non-admin machines,
# so this step installs declared formulae there in addition to casks.
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
    debug "Installing Homebrew packages..."
    brew_quiet("update")
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

  def install_and_reset
    output, exit_status = install_packages
    log_installation_results(output, exit_status)
    @packages_installed_status = nil
  end

  def packages_already_installed?
    return @packages_installed_status unless @packages_installed_status.nil?

    output, status = brew_quiet("bundle", "check", "--file=#{@brewfile_path}", "--no-upgrade")
    @packages_installed_status = status == 0
    @packages_installed_error = output unless @packages_installed_status
    @packages_installed_status
  end

  def add_missing_packages_error
    message = "Some Homebrew packages are not installed"
    details = @packages_installed_error.to_s.strip
    add_error(details.empty? ? message : "#{message}: #{details}")
  end

  def install_packages
    environment = {"HOMEBREW_NO_AUTO_UPDATE" => "1", "HOMEBREW_NO_ENV_HINTS" => "1", "HOMEBREW_CASK_OPTS" => cask_opts}
    @system.execute(env_command(environment, "brew", "bundle", "install", "--file=#{@brewfile_path}"))
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
      *formulae.map { |package| "brew \"#{package}\"" },
      *@config.brew_casks.map { |cask| "cask \"#{cask}\"" }
    ].join("\n") + "\n"
  end

  def brewfile_needed?
    formulae.any? || @config.brew_casks.any?
  end

  def formulae
    return [] if user_has_admin_rights?

    @formulae ||= fetch_formulae
  end

  def fetch_formulae
    output, status = execute(command("mise", "-C", @home, "bootstrap", "packages", "status", "--json"))
    return [] unless status == 0

    JSON.parse(output).fetch("brew", {}).fetch("packages", []).map { |package| package["package"] }
  rescue JSON::ParserError
    []
  end

  def cask_opts
    user_has_admin_rights? ? "" : "--appdir=~/Applications"
  end
end
