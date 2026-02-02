class Dotfiles::Step::UpgradeBrewPackagesStep < Dotfiles::Step
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
    output, = @system.execute("brew outdated --quiet")
    debug("brew outdated --quiet output: #{output.inspect}")
    packages = output.lines.map(&:strip).reject(&:empty?)
    return if packages.empty?

    add_notice(
      title: "🍺 Homebrew Updates Available",
      message: "#{packages.count} package(s) have updates available.\n\nRun 'brew upgrade' to update them."
    )
  end
end
