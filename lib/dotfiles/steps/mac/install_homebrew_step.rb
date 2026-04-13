class Dotfiles::Step::InstallHomebrewStep < Dotfiles::Step
  macos_only

  BREW_BINARIES = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew", "/home/linuxbrew/.linuxbrew/bin/brew"].freeze

  def should_run?
    !preferred_homebrew_installed?
  end

  def run
    user_has_admin_rights? ? install_shared_homebrew : install_private_homebrew
    configure_shell_environment
  end

  def complete?
    super
    return true if preferred_homebrew_installed?

    add_error("Homebrew is not installed")
    false
  end

  private

  def preferred_homebrew_installed?
    return command_exists?("brew") if user_has_admin_rights?

    @system.file_exist?(private_brew_bin)
  end

  def install_shared_homebrew
    debug "Installing Homebrew..."
    execute('NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"')
  end

  def install_private_homebrew
    prefix = private_brew_prefix
    debug "Installing private Homebrew to #{prefix}..."
    execute("mkdir -p '#{File.dirname(prefix)}'")
    execute("git clone --depth=1 https://github.com/Homebrew/brew '#{prefix}'") unless @system.dir_exist?(File.join(prefix, ".git"))
    execute("mkdir -p '#{File.join(prefix, "Cellar")}' '#{File.join(prefix, "Caskroom")}' '#{File.join(@home, "Library", "Caches", "Homebrew")}'")
  end

  def configure_shell_environment
    brew_bin = preferred_brew_bin
    return unless brew_bin

    add_shellenv_to_zprofile(brew_bin)
    add_brew_to_path(brew_bin)
  end

  def preferred_brew_bin
    return private_brew_bin if @system.file_exist?(private_brew_bin)

    BREW_BINARIES.find { |path| @system.file_exist?(path) }
  end

  def private_brew_prefix
    File.join(@home, ".homebrew")
  end

  def private_brew_bin
    File.join(private_brew_prefix, "bin", "brew")
  end

  def add_shellenv_to_zprofile(brew_bin)
    zprofile_path = File.join(@home, ".zprofile")
    content = @system.file_exist?(zprofile_path) ? @system.read_file(zprofile_path) : ""
    shellenv_line = "eval \"$(#{brew_bin} shellenv)\"\n"
    return if content.include?(shellenv_line)

    @system.write_file(zprofile_path, content + shellenv_line)
  end

  def add_brew_to_path(brew_bin)
    brew_bin_dir = File.dirname(brew_bin)
    path_entries = ENV.fetch("PATH", "").split(":")
    ENV["PATH"] = ([brew_bin_dir] + path_entries).uniq.join(":") unless path_entries.include?(brew_bin_dir)
  end
end
