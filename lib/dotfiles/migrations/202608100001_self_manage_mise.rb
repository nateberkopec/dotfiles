class Dotfiles::Migration::SelfManageMise < Dotfiles::Migration
  VERSION = 202608100001
  HOMEBREW_ENV = {
    "HOMEBREW_NO_AUTO_UPDATE" => "1",
    "HOMEBREW_NO_ENV_HINTS" => "1"
  }.freeze
  APT_FILES = %w[
    /etc/apt/sources.list.d/mise.list
    /etc/apt/sources.list.d/mise.sources
    /usr/share/keyrings/mise-archive-keyring.gpg
  ].freeze

  def up
    verify_self_managed_mise
    remove_homebrew_mise
    remove_apt_mise
  end

  def down
    raise NotImplementedError, "This migration transfers mise ownership and cannot be safely reversed."
  end

  private

  def verify_self_managed_mise
    mise_bin = File.join(@home, ".local", "bin", "mise")
    raise "Self-managed mise is missing at #{mise_bin}" unless @system.file_exist?(mise_bin)

    execute(command(mise_bin, "--version"))
  end

  def remove_homebrew_mise
    return unless command_exists?("brew")
    return unless command_succeeds?(brew_command("list", "--formula", "mise"))

    execute(brew_command("uninstall", "mise"))
  end

  def remove_apt_mise
    return unless @system.debian?

    if command_succeeds?(command("dpkg-query", "--show", "mise"))
      execute(command("sudo", "apt-get", "remove", "--yes", "mise"))
    end

    files = APT_FILES.select { |path| @system.file_exist?(path) }
    execute(shell_script('sudo rm -f "$@"', *files)) unless files.empty?
  end

  def brew_command(*args)
    env_command(HOMEBREW_ENV, "brew", *args)
  end
end
