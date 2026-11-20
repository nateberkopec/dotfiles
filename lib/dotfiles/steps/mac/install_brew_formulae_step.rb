require "json"

class Dotfiles::Step::InstallBrewFormulaeStep < Dotfiles::Step
  DESCRIPTION = "Installs mise-declared Homebrew formulae on non-admin machines, whose private prefix mise cannot target.".freeze
  SUDO_REQUIRED = false # Homebrew supports CI and a non-admin user's private prefix.

  macos_only
  prepend Dotfiles::Step::Sudoable

  def initialize(**kwargs)
    super
    @install_failures = {}
  end

  def should_run?
    @installed_formulae = nil
    formulae.any? { |name| !installed?(name) }
  end

  def run
    return if formulae.empty?

    debug "Installing Homebrew formulae..."
    @system.execute!(env_command({"HOMEBREW_NO_ENV_HINTS" => "1"}, "brew", "update-if-needed"))
    @installed_formulae = nil
    2.times do
      formulae.each { |name| install(name) unless installed?(name) }
    end
  end

  def complete?
    super
    @installed_formulae = nil
    formulae.each do |name|
      next if installed?(name)

      add_error(@install_failures.fetch(name, "Homebrew formula not installed: #{name}"), fix: "brew install --formula #{name}")
    end
    errors.empty?
  end

  private

  def installed?(name)
    installed_formulae.include?(name)
  end

  def installed_formulae
    @installed_formulae ||= begin
      output, status = brew_quiet("list", "--formula", "-1")
      (status == 0) ? output.lines.map(&:strip).reject(&:empty?) : []
    end
  end

  def install(name)
    install_command = env_command({"HOMEBREW_NO_AUTO_UPDATE" => "1", "HOMEBREW_NO_ENV_HINTS" => "1"}, "brew", "install", "--formula", name)
    output, status = execute(install_command)
    @installed_formulae = nil
    if status == 0
      @install_failures.delete(name)
    else
      @install_failures[name] = "Homebrew formula #{name}: #{format_command_error(install_command, status, output)}"
    end
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
end
