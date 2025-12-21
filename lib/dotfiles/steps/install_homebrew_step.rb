class Dotfiles::Step::InstallHomebrewStep < Dotfiles::Step
  attr_reader :skipped_due_to_admin

  BREW_BINARIES = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].freeze

  def initialize(**kwargs)
    super
    @skipped_due_to_admin = false
  end

  def should_run?
    !command_exists?("brew")
  end

  def run
    unless user_has_admin_rights?
      debug "Skipping Homebrew installation: no admin rights"
      @skipped_due_to_admin = true
      return
    end

    debug "Installing Homebrew..."
    execute('/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"')

    brew_bin = BREW_BINARIES.find { |path| @system.file_exist?(path) }

    zprofile_path = File.join(@home, ".zprofile")
    existing_content = @system.file_exist?(zprofile_path) ? @system.read_file(zprofile_path) : ""
    if brew_bin
      shellenv_line = "eval \"$(#{brew_bin} shellenv)\""
      unless existing_content.include?(shellenv_line) || existing_content.include?("brew shellenv")
        @system.write_file(zprofile_path, existing_content + shellenv_line + "\n")
      end

      brew_bin_dir = File.dirname(brew_bin)
      path_entries = ENV.fetch("PATH", "").split(":")
      ENV["PATH"] = ([brew_bin_dir] + path_entries).uniq.join(":") unless path_entries.include?(brew_bin_dir)
    end
  end

  def complete?
    super
    return true if command_exists?("brew")
    return true if @skipped_due_to_admin

    add_error("Homebrew is not installed")
    false
  end
end
