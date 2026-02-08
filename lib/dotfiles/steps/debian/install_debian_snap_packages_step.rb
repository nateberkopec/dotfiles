require "shellwords"

class Dotfiles::Step::InstallDebianSnapPackagesStep < Dotfiles::Step
  debian_only

  def self.display_name
    "Debian Snap Packages"
  end

  def self.depends_on
    [Dotfiles::Step::InstallDebianPackagesStep]
  end

  def should_run?
    allowed_on_platform? && configured? && missing_packages.any?
  end

  def run
    return unless configured?
    return unless ensure_snap_available

    missing_packages.each { |pkg| install_snap(pkg) }
  end

  def complete?
    super
    return true unless configured?
    return false unless ensure_snap_available

    missing_packages.each { |pkg| add_error("Snap package not installed: #{pkg[:name]}") }
    missing_packages.empty?
  end

  private

  def configured?
    configured_packages.any?
  end

  def configured_packages
    @configured_packages ||= @config.fetch("debian_snap_packages", []).map { |entry| normalize_entry(entry) }.reject { |pkg| pkg[:name].empty? }
  end

  def normalize_entry(entry)
    case entry
    when Hash
      name = entry["name"] || entry["snap"]
      {
        name: name.to_s,
        classic: entry["classic"] || false
      }
    else
      {name: entry.to_s, classic: false}
    end
  end

  def missing_packages
    return configured_packages unless snap_available?
    configured_packages.reject { |pkg| snap_installed?(pkg[:name]) }
  end

  def snap_available?
    command_exists?("snap")
  end

  def ensure_snap_available
    return true if snap_available?
    add_error("snap not available; install snapd to manage Debian snap packages")
    false
  end

  def snap_installed?(name)
    command_succeeds?("snap list #{Shellwords.shellescape(name)} >/dev/null 2>&1")
  end

  def install_snap(pkg)
    args = ["snap", "install", pkg[:name]]
    args << "--classic" if pkg[:classic]
    output, status = execute("#{sudo_prefix}#{args.join(" ")}")
    return if status == 0
    add_error("snap install #{pkg[:name]} failed (status #{status}): #{output}")
  end
end
