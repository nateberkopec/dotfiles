class Dotfiles::Step::InstallOrbstackAppStep < Dotfiles::Step
  DESCRIPTION = "Installs the pinned OrbStack release without Homebrew's blocking postflight.".freeze
  VERSION = "2.2.3".freeze
  BUILD = "20963".freeze
  SHA256 = "7ca77868f3a0d7d9f57b3f98615aad30cc59d23cc84bbff13f78846df0b493d4".freeze
  URL = "https://cdn-updates.orbstack.dev/arm64/OrbStack_v#{VERSION}_#{BUILD}_arm64.dmg".freeze

  macos_only
  include Dotfiles::Step::DmgInstallable

  def should_run?
    !app_installed?
  end

  def run
    return if app_installed?

    install_dmg_app
    add_notice(title: "OrbStack setup", message: "Open OrbStack once to finish setup; it installs its CLI and keeps itself updated.")
  end

  def complete?
    super
    add_error("OrbStack.app is not installed in #{File.dirname(destination)}") unless app_installed?
    errors.empty?
  end

  private

  def app_name
    "OrbStack"
  end

  def destination
    @destination ||= File.join(user_has_admin_rights? ? "/Applications" : File.join(@home, "Applications"), "OrbStack.app")
  end
end
