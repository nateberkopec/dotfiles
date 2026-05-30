class Dotfiles::Migration::ApplyPackageReleasePolicies < Dotfiles::Migration
  VERSION = 202605310002

  def up
    apply_mise_release_age
    apply_homebrew_auto_update_secs
  end

  def down
    raise NotImplementedError, "This migration updates user package-manager policy and cannot be safely reversed."
  end

  private

  def apply_mise_release_age
    return unless command_exists?("mise")

    execute(command("mise", "settings", "set", "minimum_release_age", "3d"))
  end

  def apply_homebrew_auto_update_secs
    return unless command_exists?("fish")

    execute(command("fish", "-c", "set -Ux HOMEBREW_AUTO_UPDATE_SECS 604800"))
  end
end
