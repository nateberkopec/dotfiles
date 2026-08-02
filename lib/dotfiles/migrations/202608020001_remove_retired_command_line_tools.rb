class Dotfiles::Migration::RemoveRetiredCommandLineTools < Dotfiles::Migration
  VERSION = 202608020001
  HOMEBREW_FORMULAE = %w[asdf gemini-cli thefuck].freeze

  def up
    remove_homebrew_formulae
    remove_debian_thefuck
    remove_managed_files
  end

  def down
    raise NotImplementedError, "This migration removes retired command-line tools and cannot be safely reversed."
  end

  private

  def remove_homebrew_formulae
    return unless @system.macos?

    HOMEBREW_FORMULAE.each do |formula|
      next unless command_succeeds?(brew_command("list", "--formula", formula))

      execute(brew_command("uninstall", formula))
    end
  end

  def remove_debian_thefuck
    return unless @system.debian?
    return unless command_succeeds?(command("dpkg-query", "--show", "thefuck"))

    execute(command("sudo", "apt-get", "remove", "--yes", "thefuck"))
  end

  def remove_managed_files
    @system.rm_rf(File.join(@home, ".config", "fish", "functions", "fuck.fish"))
    @system.rm_rf(File.join(@home, ".gemini", "extensions", "nanobanana"))
  end

  def brew_command(*args)
    env_command({"HOMEBREW_NO_AUTO_UPDATE" => "1", "HOMEBREW_NO_ENV_HINTS" => "1"}, "brew", *args)
  end
end
