class Dotfiles::Migration::RemoveFactoryDroid < Dotfiles::Migration
  VERSION = 202608240001

  def up
    uninstall_homebrew_cask
    remove_user_files
  end

  def down
    raise NotImplementedError, "This migration removes Factory Droid and cannot be safely reversed."
  end

  private

  def uninstall_homebrew_cask
    return unless @system.macos?
    return unless command_succeeds?(brew_command("list", "--cask", "droid"))

    execute(brew_command("uninstall", "--cask", "droid"))
  end

  def remove_user_files
    [
      File.join(@home, ".factory"),
      File.join(@home, ".local", "bin", "droid"),
      File.join(@home, ".cargo", "bin", "droid")
    ].each { |path| @system.rm_rf(path) }
  end

  def brew_command(*args)
    env_command({"HOMEBREW_NO_AUTO_UPDATE" => "1", "HOMEBREW_NO_ENV_HINTS" => "1"}, "brew", *args)
  end
end
