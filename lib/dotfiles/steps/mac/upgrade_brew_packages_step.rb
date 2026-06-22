class Dotfiles::Step::UpgradeBrewPackagesStep < Dotfiles::Step
  DESCRIPTION = "Checks for outdated Homebrew packages and reports available upgrades.".freeze

  macos_only

  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep]
  end

  def should_run?
    check_outdated_packages
    false
  end

  def complete?
    super
    true
  end

  private

  def check_outdated_packages
    output, status = brew_quiet("outdated", "--formula", "--quiet")
    debug("brew outdated --formula --quiet output: #{output.inspect}")
    return unless status == 0

    packages = managed_outdated_packages(output)
    return if packages.empty?

    add_notice(
      title: "🍺 Homebrew Updates Available",
      message: "#{packages.count} managed package(s) have updates available.\n\nRun 'brew upgrade #{packages.join(" ")}' to update them."
    )
  end

  def managed_outdated_packages(output)
    outdated_packages = output.lines.map(&:strip).reject(&:empty?)
    outdated_packages & @config.brew_packages
  end
end
