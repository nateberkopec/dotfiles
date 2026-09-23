class Dotfiles::Migration::ReplaceRaycastWithTinycast < Dotfiles::Migration
  VERSION = 202609170001

  macos_only

  def up
    return unless command_exists?("brew")
    return unless command_succeeds?(homebrew_command("list", "--cask", "raycast"))

    execute(homebrew_command("uninstall", "--cask", "raycast"))
  end

  def down
    raise NotImplementedError, "This migration permanently replaces Raycast with Tinycast."
  end
end
