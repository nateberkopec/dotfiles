class Dotfiles::Step::UpgradeBrewPackagesStep < Dotfiles::Step
  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep]
  end

  def initialize(**kwargs)
    super
    @brewfile_path = File.join(@dotfiles_dir, "Brewfile")
    @outdated_packages = nil
  end

  def should_run?
    !outdated_packages.empty?
  end

  def run
    debug "Upgrading Homebrew packages..."
    outdated_packages.each do |package|
      debug "  Upgrading #{package}..."
      brew_quiet("upgrade #{package}")
    end
  end

  def complete?
    return true if ran?
    outdated_packages.empty?
  end

  def update
  end

  private

  def outdated_packages
    return @outdated_packages unless @outdated_packages.nil?

    @outdated_packages = []
    @outdated_packages.concat(check_outdated_type("brew", "formula"))
    @outdated_packages.concat(check_outdated_type("cask", "cask"))

    debug "Found #{@outdated_packages.length} outdated packages" if @outdated_packages.any?
    @outdated_packages
  end

  def check_outdated_type(brewfile_type, brew_flag)
    managed_packages = extract_packages_from_brewfile(brewfile_type)
    return [] if managed_packages.empty?

    outdated_output, = @system.execute("HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --#{brew_flag} #{managed_packages.join(" ")} 2>/dev/null")
    outdated_output.split("\n").reject(&:empty?)
  end

  def extract_packages_from_brewfile(type)
    return [] unless @system.file_exist?(@brewfile_path)

    content = @system.read_file(@brewfile_path)
    packages = []

    content.each_line do |line|
      if line.strip.start_with?("#{type} ")
        package = line.match(/#{type}\s+"([^"]+)"/)
        packages << package[1] if package
      end
    end

    packages
  end
end
