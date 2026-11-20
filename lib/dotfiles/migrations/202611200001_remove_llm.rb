class Dotfiles::Migration::RemoveLlm < Dotfiles::Migration
  VERSION = 202611200001

  def up
    return unless @system.macos?

    execute(brew_command("uninstall", "llm")) if command_succeeds?(brew_command("list", "--formula", "llm"))
    @system.rm_rf(File.join(@home, "Library", "Application Support", "io.datasette.llm"))
  end

  def down
    raise NotImplementedError, "This migration removes Simon Willison's llm CLI and its stored keys and cannot be safely reversed."
  end

  private

  def brew_command(*args)
    env_command({"HOMEBREW_NO_AUTO_UPDATE" => "1", "HOMEBREW_NO_ENV_HINTS" => "1"}, "brew", *args)
  end
end
