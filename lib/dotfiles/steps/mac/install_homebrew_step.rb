class Dotfiles::Step::InstallHomebrewStep < Dotfiles::Step
  macos_only

  attr_reader :skipped_due_to_admin

  BREW_BINARIES = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew", "/home/linuxbrew/.linuxbrew/bin/brew"].freeze

  def initialize(**kwargs)
    super
    @skipped_due_to_admin = false
  end

  def should_run?
    !command_exists?("brew")
  end

  def run
    return skip_without_admin unless user_has_admin_rights?
    install_homebrew
    configure_shell_environment
  end

  def skip_without_admin
    debug "Skipping Homebrew installation: no admin rights"
    @skipped_due_to_admin = true
  end

  def install_homebrew
    debug "Installing Homebrew..."
    execute('NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"')
  end

  def configure_shell_environment
    brew_bin = BREW_BINARIES.find { |path| @system.file_exist?(path) }
    return unless brew_bin
    add_shellenv_to_zprofile(brew_bin)
    add_brew_to_path(brew_bin)
  end

  def add_shellenv_to_zprofile(brew_bin)
    zprofile_path = File.join(@home, ".zprofile")
    content = @system.file_exist?(zprofile_path) ? @system.read_file(zprofile_path) : ""
    return if content.include?("brew shellenv")
    @system.write_file(zprofile_path, content + "eval \"$(#{brew_bin} shellenv)\"\n")
  end

  def add_brew_to_path(brew_bin)
    brew_bin_dir = File.dirname(brew_bin)
    path_entries = ENV.fetch("PATH", "").split(":")
    ENV["PATH"] = ([brew_bin_dir] + path_entries).uniq.join(":") unless path_entries.include?(brew_bin_dir)
  end

  def complete?
    super
    return true if command_exists?("brew")
    return true if @skipped_due_to_admin

    add_error("Homebrew is not installed")
    false
  end
end
