class Dotfiles::Step::InstallBrewPackagesStep < Dotfiles::Step
  DESCRIPTION = "Installs command-line tools from the repository Brewfile using Homebrew.".freeze

  macos_only

  def self.depends_on
    [Dotfiles::Step::UpdateHomebrewStep]
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
    reset_package_status
  end

  def complete?
    super
    unless @system.file_exist?(@brewfile_path)
      add_error("Brewfile does not exist at #{@brewfile_path}")
      return false
    end
    add_missing_packages_error unless packages_already_installed?
    @packages_installed_status
  end

  def update
  end

  private

  def packages_already_installed?
    return @packages_installed_status unless @packages_installed_status.nil?

    output, status = brew_quiet("bundle check --file=#{@brewfile_path} --no-upgrade")
    @packages_installed_status = status == 0
    @packages_installed_error = output unless @packages_installed_status
    debug "All packages already installed" if @packages_installed_status
    @packages_installed_status
  end

  def reset_package_status
    @packages_installed_status = nil
    @packages_installed_error = nil
  end

  def add_missing_packages_error
    message = "Some Homebrew packages are not installed"
    details = @packages_installed_error.to_s.strip
    message = "#{message}: #{details}" unless details.empty?
    add_error(message)
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
    [
      "No admin rights detected.",
      *skipped_items_lines("formulae", skipped[:packages]),
      *skipped_items_lines("casks", skipped[:casks])
    ].join("\n")
  end

  def skipped_items_lines(label, items)
    return [] if items.empty?
    ["\nSkipped #{label}:", *items.map { |item| "• #{item}" }]
  end

  def log_installation_results(output, exit_status)
    return if exit_status == 0

    debug "brew bundle install exited with status #{exit_status}"
    debug "Output:\n#{output}" if @debug
  end

  def generate_brewfile
    brew_config = @config.packages&.dig("brew") || {}
    content = build_brewfile_content(brew_config)
    @system.write_file(@brewfile_path, content)
  end

  def build_brewfile_content(brew_config)
    [
      *(brew_config["packages"] || []).map { |pkg| "brew \"#{pkg}\"" },
      *(brew_config["casks"] || []).map { |cask| "cask \"#{cask}\"" }
    ].join("\n") + "\n"
  end
end
