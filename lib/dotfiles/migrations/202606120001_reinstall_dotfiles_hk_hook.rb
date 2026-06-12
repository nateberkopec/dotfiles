class Dotfiles::Migration::ReinstallDotfilesHkHook < Dotfiles::Migration
  VERSION = 202606120001

  LEGACY_HOOK_NAME = "hk-pre-commit"

  def up
    return unless command_exists?("git")
    return unless command_exists?("hk")
    return unless @system.dir_exist?(File.join(@dotfiles_dir, ".git"))

    uninstall_legacy_hook_config
    execute(shell_script('cd "$1" && hk install', @dotfiles_dir))
  end

  def down
    raise NotImplementedError, "This migration reinstalls hooks and cannot be safely reversed."
  end

  private

  def uninstall_legacy_hook_config
    execute(git_command("config", "--local", "--unset-all", "hook.#{LEGACY_HOOK_NAME}.command"))
    execute(git_command("config", "--local", "--unset-all", "hook.#{LEGACY_HOOK_NAME}.event"))
  end

  def git_command(*args)
    command("git", "-C", @dotfiles_dir, *args)
  end
end
