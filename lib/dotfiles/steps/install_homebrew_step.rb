class Dotfiles::Step::InstallHomebrewStep < Dotfiles::Step
  attr_reader :skipped_due_to_admin

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

    zprofile_path = home_path("zprofile")
    existing_content = @system.file_exist?(zprofile_path) ? @system.read_file(zprofile_path) : ""
    @system.write_file(zprofile_path, existing_content + 'eval "$(/opt/homebrew/bin/brew shellenv)"' + "\n")

    execute('eval "$(/opt/homebrew/bin/brew shellenv)"')
  end

  def complete?
    command_exists?("brew") || @skipped_due_to_admin
  end
end
