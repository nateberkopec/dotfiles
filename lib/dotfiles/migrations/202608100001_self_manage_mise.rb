class Dotfiles::Migration::SelfManageMise < Dotfiles::Migration
  VERSION = 202608100001
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
    remove_homebrew_formula("mise")
  end

  def remove_apt_mise
    remove_apt_package("mise", files: APT_FILES)
  end
end
