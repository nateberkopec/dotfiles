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
    output, status = execute(install_command)
    @install_error = format_command_error(install_command, status, output) unless status == 0
  end

  def complete?
    super
    add_error(@install_error) if @install_error
    @errors.empty?
  end

  private

  def install_command
    command("mise", "system", "install", "--yes", "--update", *package_args)
  end

  def package_args
    @package_args ||= (brew_package_args + apt_package_args).uniq
  end

  def brew_package_args
    return [] if @system.debian?
    return [] if @system.macos? && !user_has_admin_rights?

    @config.brew_packages.map { |package| "brew:#{package}" }
  end

  def apt_package_args
    return [] unless @system.debian?

    packages = @config.debian_packages - @config.debian_non_apt_packages
    packages.reject { |package| package == "docker.io" && command_exists?("docker") }.map { |package| "apt:#{package}" }
  end
end
