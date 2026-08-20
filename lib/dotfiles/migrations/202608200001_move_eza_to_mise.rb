class Dotfiles::Migration::MoveEzaToMise < Dotfiles::Migration
  VERSION = 202608200001
  APT_FILES = %w[
    /etc/apt/sources.list.d/gierens.list
    /usr/share/keyrings/gierens-archive-keyring.gpg
  ].freeze

  def up
    remove_homebrew_eza
    remove_apt_eza
  end

  def down
    raise NotImplementedError, "mise now owns eza and the previous OS package source cannot be safely restored."
  end

  private

  def remove_homebrew_eza
    remove_homebrew_formula("eza")
  end

  def remove_apt_eza
    remove_apt_package("eza", files: APT_FILES)
  end
end
