class Dotfiles::Step::UpdateDebianPackagesStep < Dotfiles::Step
  debian_only

  def self.display_name
    "Update APT Packages"
  end

  def self.depends_on
    [Dotfiles::Step::InstallDebianPackagesStep]
  end

  def should_run?
    command_exists?("apt-get")
  end

  def run
    update_apt
    check_upgradable_packages
  end

  def complete?
    super
    true
  end

  private

  def update_apt
    output, status = execute("#{sudo_prefix}DEBIAN_FRONTEND=noninteractive apt-get update -y")
    return if status == 0
    add_warning(title: "⚠️  APT Update Failed", message: output)
  end

  def check_upgradable_packages
    output, status = execute("apt list --upgradable 2>/dev/null", quiet: true)
    return unless status == 0

    packages = output.lines.map(&:strip).reject do |line|
      line.empty? || line.start_with?("Listing") || line.start_with?("WARNING")
    end
    packages = packages.map { |line| line.split("/").first }.uniq
    return if packages.empty?

    add_notice(
      title: "⬆️  APT Updates Available",
      message: "#{packages.count} package(s) have updates available.\n\nRun 'sudo apt-get upgrade' to update them."
    )
  end
end
