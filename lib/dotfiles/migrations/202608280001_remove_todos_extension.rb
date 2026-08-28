class Dotfiles::Migration::RemoveTodosExtension < Dotfiles::Migration
  VERSION = 202608280001

  def up
    @system.rm_rf(File.join(@home, ".pi", "agent", "extensions", "todos.ts"))
  end

  def down
    raise NotImplementedError, "This migration removes the retired todos extension and cannot be safely reversed."
  end
end
