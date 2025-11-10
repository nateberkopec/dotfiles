class Dotfiles::Step::UpgradeBrewPackagesStep < Dotfiles::Step
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
    output, = @system.execute("brew upgrade -n")
    debug("brew upgrade -n output: #{output.inspect}")
    return if output.strip.empty?

    package_count = output.strip.split("\n").size - 1
    add_notice(
      title: "🍺 Homebrew Updates Available",
      message: "#{package_count} package(s) have updates available.\n\nRun 'brew upgrade' to update them."
    )
  end
end
