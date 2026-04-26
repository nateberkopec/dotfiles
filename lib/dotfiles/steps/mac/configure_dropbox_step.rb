class Dotfiles::Step::ConfigureDropboxStep < Dotfiles::Step
  DESCRIPTION = "Launches Dropbox and reports any manual setup still required.".freeze

  prepend Dotfiles::Step::Sudoable

  macos_only

  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep]
  end

  def should_run?
    dropbox_installed? && !dropbox_configured?
  end

  def run
    debug "Configuring Dropbox..."
    launch_dropbox_app
    add_setup_notice
  end

  def complete?
    super
    return true unless dropbox_installed?

    unless dropbox_configured?
      add_error("Dropbox is installed but not configured (no Dropbox folder found)")
      return false
    end

    true
  end

  private

  def dropbox_installed?
    @system.dir_exist?("/Applications/Dropbox.app")
  end

  def dropbox_configured?
    dropbox_folder = File.join(@home, "Dropbox")
    cloud_storage_dropbox = File.join(@home, "Library", "CloudStorage", "Dropbox")
    @system.dir_exist?(dropbox_folder) || @system.dir_exist?(cloud_storage_dropbox)
  end

  def launch_dropbox_app
    debug "Launching Dropbox application..."
    @system.execute(command("open", "-a", "Dropbox"))
  end

  def add_setup_notice
    add_notice(
      title: "📦 Dropbox Setup Required",
      message: notice_message
    )
  end

  def notice_message
    [
      "Dropbox has been installed and launched.",
      "",
      "Please complete the setup:",
      "• Sign in to your Dropbox account",
      "• Complete the initial setup wizard",
      "• Choose your sync preferences",
      "",
      "The installer will mark this step complete once",
      "your Dropbox folder is created at ~/Dropbox or",
      "~/Library/CloudStorage/Dropbox/"
    ].join("\n")
  end
end
