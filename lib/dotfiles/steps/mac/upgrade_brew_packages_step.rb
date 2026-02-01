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
    output, = @system.execute("brew upgrade -n")
    debug("brew upgrade -n output: #{output.inspect}")
    return if output.strip.empty?

    first_line = output.strip.split("\n").first
    package_count = first_line[/Would upgrade (\d+) outdated package/, 1]&.to_i || 0
    return if package_count.zero?

    add_notice(
      title: "🍺 Homebrew Updates Available",
      message: "#{package_count} package(s) have updates available.\n\nRun 'brew upgrade' to update them."
    )
  end
end
