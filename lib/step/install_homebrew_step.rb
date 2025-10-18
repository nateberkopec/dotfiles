class InstallHomebrewStep < Step
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

    File.open(@config.expand_path("zprofile"), "a") do |f|
      f.puts 'eval "$(/opt/homebrew/bin/brew shellenv)"'
    end

    execute('eval "$(/opt/homebrew/bin/brew shellenv)"')
  end

  def complete?
    command_exists?("brew") || @skipped_due_to_admin
  end
end
