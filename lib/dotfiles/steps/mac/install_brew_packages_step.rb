class Dotfiles::Step::InstallBrewPackagesStep < Dotfiles::Step
  macos_only

  BREW_RETRYABLE_ERRORS = [
    "already locked",
    "has already locked",
    "Could not obtain lock",
    "Another active Homebrew update process is already in progress"
  ].freeze

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
    ensure_fish_installed
    output, exit_status = install_packages
    check_skipped_packages
    log_installation_results(output, exit_status)
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

  def ensure_fish_installed
    return unless preinstall_fish?

    debug "Installing fish separately before brew bundle for a deterministic shell setup..."
    output, status = install_formula_with_retries("fish")
    return if status == 0

    debug "brew install fish exited with status #{status}"
    debug "Output:\n#{output}" if @debug
  end

  def preinstall_fish?
    !user_has_admin_rights? && @config.packages["brew"]["packages"].include?("fish") && !brew_formula_installed?("fish")
  end

  def install_formula_with_retries(name, retries: 3)
    output = ""
    status = nil

    retries.times do |attempt|
      output, status = brew_install_formula(name)
      return [output, 0] if status == 0 || brew_formula_installed?(name)
      break unless retryable_brew_error?(output)

      sleep(3 * (attempt + 1))
    end

    [output, status]
  end

  def brew_install_formula(name)
    @system.execute("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew install #{name} 2>&1")
  end

  def brew_formula_installed?(name)
    _, status = brew_quiet("list --formula #{name}")
    status == 0
  end

  def retryable_brew_error?(output)
    BREW_RETRYABLE_ERRORS.any? { |message| output.include?(message) }
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
