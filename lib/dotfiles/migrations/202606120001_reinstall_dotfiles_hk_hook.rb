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
    unset_legacy_hook_config("command")
    unset_legacy_hook_config("event")
  end

  def unset_legacy_hook_config(key)
    config_key = "hook.#{LEGACY_HOOK_NAME}.#{key}"
    return unless command_succeeds?(git_command("config", "--local", "--get-all", config_key))

    execute(git_command("config", "--local", "--unset-all", config_key))
  end

  def git_command(*args)
    command("git", "-C", @dotfiles_dir, *args)
  end
end
