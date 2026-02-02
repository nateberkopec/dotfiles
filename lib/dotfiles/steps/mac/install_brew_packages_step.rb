class Dotfiles::Step::InstallBrewPackagesStep < Dotfiles::Step
  macos_only

  def self.depends_on
    [Dotfiles::Step::InstallHomebrewStep, Dotfiles::Step::UpdateHomebrewStep]
  end

  def initialize(**kwargs)
    super
    @brewfile_path = File.join(@dotfiles_dir, "Brewfile")
    @packages_installed_status = nil
  end

  def should_run?
    generate_brewfile
    !packages_already_installed?
  end

  def run
    debug "Installing command-line tools via Homebrew..."
    output, exit_status = install_packages
    check_skipped_packages
    log_installation_results(output, exit_status)
  end

  def packages_already_installed?
    return @packages_installed_status unless @packages_installed_status.nil?

    _, status = brew_quiet("bundle check --file=#{@brewfile_path} --no-upgrade")
    @packages_installed_status = status == 0
    debug "All packages already installed" if @packages_installed_status
    @packages_installed_status
  end

  def install_packages
    cask_opts = user_has_admin_rights? ? "" : "--appdir=~/Applications"
    @system.execute("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_CASK_OPTS=\"#{cask_opts}\" brew bundle install --file=#{@brewfile_path} 2>&1")
  end

  def check_skipped_packages
    skipped = find_skipped_packages
    return if skipped[:packages].empty? && skipped[:casks].empty?
    add_warning(title: "⚠️  Homebrew Installation Skipped", message: format_skipped_warning(skipped))
  end

  def find_skipped_packages
    installed_formulae = brew_quiet("list --formula").first.split("\n")
    installed_casks = brew_quiet("list --cask").first.split("\n")
    {
      packages: @config.packages["brew"]["packages"].reject { |pkg| installed_formulae.include?(pkg) },
      casks: @config.packages["brew"]["casks"].reject { |cask| installed_casks.include?(cask.split("/").last) }
    }
  end

  def format_skipped_warning(skipped)
    lines = ["No admin rights detected."]
    append_skipped_items(lines, "formulae", skipped[:packages])
    append_skipped_items(lines, "casks", skipped[:casks])
    lines.join("\n")
  end

  def append_skipped_items(lines, label, items)
    return if items.empty?
    lines.concat(["\nSkipped #{label}:"] + items.map { |item| "• #{item}" })
  end

  def log_installation_results(output, exit_status)
    return if exit_status == 0

    debug "brew bundle install exited with status #{exit_status}"
    debug "Output:\n#{output}" if @debug
  end

  def complete?
    super
    return true if ran?
    unless @system.file_exist?(@brewfile_path)
      add_error("Brewfile does not exist at #{@brewfile_path}")
      return false
    end
    raise "packages_already_installed? must be called before complete?" if @packages_installed_status.nil?
    add_error("Some Homebrew packages are not installed") unless @packages_installed_status
    @packages_installed_status
  end

  def update
  end

  private

  def generate_brewfile
    brew_config = @config.packages&.dig("brew") || {}
    content = build_brewfile_content(brew_config)
    @system.write_file(@brewfile_path, content)
  end

  def build_brewfile_content(brew_config)
    lines = (brew_config["packages"] || []).map { |pkg| "brew \"#{pkg}\"" }
    lines += (brew_config["casks"] || []).map { |cask| "cask \"#{cask}\"" }
    lines.join("\n") + "\n"
  end
end
