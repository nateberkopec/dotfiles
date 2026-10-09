require "json"

# Mise cannot target the private Homebrew prefix used by non-admin machines,
# so this step installs declared formulae there in addition to casks.
class Dotfiles::Step::InstallBrewCasksStep < Dotfiles::Step
  DESCRIPTION = "Installs Homebrew casks, plus formulae on non-admin machines.".freeze
  SUDO_REQUIRED = false # Homebrew supports CI and a non-admin user's private prefix.
  CASK_INSTALL_TIMEOUT_SECONDS = 600

  macos_only
  prepend Dotfiles::Step::Sudoable

  def initialize(**kwargs)
    super
    @install_failures = {}
  end

  def should_run?
    packages.any? { |type, name| !installed?(type, name) }
  end

  def run
    debug "Installing Homebrew packages..."
    @system.execute!(env_command({"HOMEBREW_NO_ENV_HINTS" => "1"}, "brew", "update-if-needed"))
    2.times do
      packages.each do |type, name|
        next if installed?(type, name)

        install(type, name)
      end
    end
  end

  def complete?
    super
    notify_admin_only_casks
    packages.each do |type, name|
      next if installed?(type, name)

      add_error(@install_failures.fetch([type, name], "Homebrew #{type} not installed: #{name}"))
    end
    errors.empty?
  end

  private

  def packages
    formulae.map { |name| ["formula", name] } + (@config.brew_casks - admin_only_casks).map { |name| ["cask", name] }
  end

  def admin_only_casks
    return [] if user_has_admin_rights? || @config.brew_casks.empty?

    @admin_only_casks ||= fetch_pkg_casks
  end

  def fetch_pkg_casks
    output, status = brew_quiet("info", "--cask", "--json=v2", *@config.brew_casks)
    return [] unless status == 0

    tokens = pkg_tokens(JSON.parse(output))
    @config.brew_casks.select { |name| tokens.include?(name.split("/").last) }
  rescue JSON::ParserError
    []
  end

  def pkg_tokens(info)
    pkg_casks = info.fetch("casks", []).select { |cask| cask.fetch("artifacts", []).any? { |artifact| artifact.key?("pkg") } }
    pkg_casks.map { |cask| cask.fetch("token") }
  end

  def notify_admin_only_casks
    return if admin_only_casks.empty? || notices.any?

    add_notice(title: "Casks that need an admin", message: "These casks run a system installer, so ask this Mac's admin to install them: #{admin_only_casks.join(", ")}")
  end

  def installed?(type, name)
    lookup_name = (type == "cask") ? name.split("/").last : name
    output, status = brew_quiet("list", "--#{type}", "--versions", lookup_name)
    status == 0 && !output.strip.empty?
  end

  def install(type, name)
    args = ["brew", "install", "--#{type}"]
    args << "--adopt" if type == "cask"
    args << "--appdir=#{@home}/Applications" if type == "cask" && !user_has_admin_rights?
    args << name
    install_command = env_command({"HOMEBREW_NO_AUTO_UPDATE" => "1", "HOMEBREW_NO_ENV_HINTS" => "1"}, *args)
    output, status = execute(install_command, timeout: (type == "cask") ? CASK_INSTALL_TIMEOUT_SECONDS : nil)
    if status == 0
      @install_failures.delete([type, name])
    else
      @install_failures[[type, name]] = "Homebrew #{type} #{name}: #{format_command_error(install_command, status, output)}"
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
