class Dotfiles::Step::InstallSystemPackagesStep < Dotfiles::Step
  DESCRIPTION = "Installs configured system packages with mise.".freeze

  def self.depends_on
    [Dotfiles::Step::InstallDebianPackagesStep]
  end

  def should_run?
    package_args.any?
  end

  def run
    return if package_args.empty?

    @install_error = nil
    install_commands.each do |install_command|
      output, status = execute(install_command)
      next if status == 0

      @install_error = format_command_error(install_command, status, output)
      break
    end
  end

  def complete?
    super
    add_error(@install_error) if @install_error
    @errors.empty?
  end

  private

  def install_commands
    return [mise_install_command] if mise_system_available?
    return [apt_update_command, apt_install_command] if @system.debian?

    [brew_install_command]
  end

  def mise_install_command
    command("mise", "system", "install", "--yes", "--update", *package_args)
  end

  def apt_update_command
    sudo_command("env", "DEBIAN_FRONTEND=noninteractive", "apt-get", "update", "-y")
  end

  def apt_install_command
    sudo_command("env", "DEBIAN_FRONTEND=noninteractive", "apt-get", "install", "-y", *apt_packages)
  end

  def brew_install_command
    env_command({"HOMEBREW_NO_AUTO_UPDATE" => "1", "HOMEBREW_NO_ENV_HINTS" => "1"}, "brew", "install", *brew_packages)
  end

  def package_args
    @package_args ||= (brew_packages.map { |package| "brew:#{package}" } + apt_packages.map { |package| "apt:#{package}" }).uniq
  end

  def brew_packages
    return [] if @system.debian?
    return [] if @system.macos? && !user_has_admin_rights?

    @config.brew_packages
  end

  def apt_packages
    return [] unless @system.debian?

    packages = @config.debian_packages - @config.debian_non_apt_packages
    packages.reject { |package| package == "docker.io" && command_exists?("docker") }
  end

  def mise_system_available?
    return @mise_system_available unless @mise_system_available.nil?

    @mise_system_available = command_succeeds?(command("mise", "help", "system"))
  end
end
