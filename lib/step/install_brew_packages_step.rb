class InstallBrewPackagesStep < Step
  attr_reader :skipped_packages, :skipped_casks

  def self.depends_on
    [InstallHomebrewStep]
  end

  def initialize(**kwargs)
    super
    @skipped_packages = []
    @skipped_casks = []
    @brewfile_path = File.join(@dotfiles_dir, "Brewfile")
  end

  def run
    debug "Installing command-line tools via Homebrew..."

    generate_brewfile

    result = system("brew bundle check --file=#{@brewfile_path} --no-upgrade >/dev/null 2>&1")
    if result
      debug "All packages already installed"
      return
    end

    cask_opts = user_has_admin_rights? ? "" : "--appdir=~/Applications"
    output = `HOMEBREW_CASK_OPTS="#{cask_opts}" brew bundle install --file=#{@brewfile_path} 2>&1`
    exit_status = $?.exitstatus

    packages = @config.packages["brew"]["packages"]
    casks = @config.packages["brew"]["casks"]

    installed_formulae = `brew list --formula 2>/dev/null`.split("\n")
    installed_casks = `brew list --cask 2>/dev/null`.split("\n")

    @skipped_packages = packages.reject { |pkg| installed_formulae.include?(pkg) }
    @skipped_casks = casks.reject { |cask| installed_casks.include?(cask) }

    if exit_status != 0
      debug "brew bundle install exited with status #{exit_status}"
      debug "Output:\n#{output}" if @debug
      debug "Skipped packages: #{@skipped_packages.join(", ")}" if @skipped_packages.any?
      debug "Skipped casks: #{@skipped_casks.join(", ")}" if @skipped_casks.any?
    end
  end

  def complete?
    return true if ran?
    return false unless File.exist?(@brewfile_path)
    system("brew bundle check --file=#{@brewfile_path} --no-upgrade >/dev/null 2>&1")
  rescue
    false
  end

  def update
  end

  private

  def generate_brewfile
    packages = @config.packages["brew"]["packages"]
    cask_packages = @config.packages["brew"]["casks"]

    brewfile_content = []
    packages.each { |pkg| brewfile_content << "brew \"#{pkg}\"" }
    cask_packages.each { |cask| brewfile_content << "cask \"#{cask}\"" }

    File.write(@brewfile_path, brewfile_content.join("\n") + "\n")
  end
end
