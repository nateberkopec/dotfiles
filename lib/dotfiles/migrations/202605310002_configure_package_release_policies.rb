class Dotfiles::Migration::ConfigurePackageReleasePolicies < Dotfiles::Migration
  VERSION = 202605310002

  def up
    configure_mise_release_age
    configure_homebrew_auto_update_interval
  end

  def down
    raise NotImplementedError, "Package release policies should remain configured."
  end

  private

  def configure_mise_release_age
    return unless command_exists?("mise")

    execute(command("mise", "settings", "set", "minimum_release_age", "3d"))
  end

  def configure_homebrew_auto_update_interval
    return unless command_exists?("fish")

    execute(command("fish", "-lc", "set -Ux HOMEBREW_AUTO_UPDATE_SECS 604800"))
  end
end
