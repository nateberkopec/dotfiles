class Dotfiles::Step::UpgradeBrewPackagesStep < Dotfiles::Step
  DESCRIPTION = "Upgrades managed Homebrew packages that are already installed and outdated.".freeze

  macos_only

  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep]
  end

  def should_run?
    outdated_managed_packages.any?
  end

  def run
    @upgrade_error = nil
    upgrade_outdated_packages
    cleanup_upgraded_packages if @upgrade_error.nil?
  end

  def complete?
    super
    add_error(@upgrade_error) if @upgrade_error
    @errors.empty?
  end

  private

  def upgrade_outdated_packages
    output, status = brew_quiet("upgrade", *outdated_managed_packages)
    @upgrade_error = format_command_error(brew_upgrade_command, status, output) unless status == 0
  end

  def cleanup_upgraded_packages
    brew_quiet("cleanup", *outdated_managed_packages)
  end

  def outdated_managed_packages
    @outdated_managed_packages ||= fetch_outdated_managed_packages
  end

  def fetch_outdated_managed_packages
    output, status = brew_quiet("outdated", "--formula", "--quiet")
    debug("brew outdated --formula --quiet output: #{output.inspect}")
    return [] unless status == 0

    output.lines.map(&:strip).reject(&:empty?) & @config.brew_packages
  end

  def brew_upgrade_command
    env_command({"HOMEBREW_NO_AUTO_UPDATE" => "1", "HOMEBREW_NO_ENV_HINTS" => "1"}, "brew", "upgrade", *outdated_managed_packages)
  end
end
