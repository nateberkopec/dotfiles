class Dotfiles::Step::InstallThawAppStep < Dotfiles::Step
  DESCRIPTION = "Installs the pinned Thaw release on admin macOS machines.".freeze
  VERSION = "2.0.1".freeze
  SHA256 = "5e4a17c39075a9d27b0c9c31619cee875880befa79021d8ddc9ae6d90e345cbf".freeze
  URL = "https://github.com/thaw-app/Thaw/releases/download/#{VERSION}/Thaw.dmg".freeze

  macos_only
  include Dotfiles::Step::DmgInstallable

  def should_run?
    !ENV["CI"] && allowed_on_platform? && user_has_admin_rights? && !complete?
  end

  def run
    return if ENV["CI"]
    return unless allowed_on_platform? && user_has_admin_rights?
    return if app_installed?

    install_dmg_app
    add_notice(title: "Thaw setup", message: "Open Thaw, grant Accessibility, and choose your layout and launch-at-login settings. Thaw keeps your profiles and preferences locally.")
  end

  def complete?
    super
    return true if ENV["CI"] || !allowed_on_platform? || !user_has_admin_rights?

    add_error("Thaw.app is not installed in Applications") unless app_installed?
    errors.empty?
  end

  private

  def app_name
    "Thaw"
  end

  def destination
    "/Applications/Thaw.app"
  end
end
