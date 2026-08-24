class Dotfiles::Migration::RemoveTryLauncher < Dotfiles::Migration
  VERSION = 202608240004

  def up
    @system.rm_rf(File.join(@home, ".local", "bin", "try"))
  end

  def down
    raise NotImplementedError, "This migration removes the retired try launcher and cannot be safely reversed."
  end
end
