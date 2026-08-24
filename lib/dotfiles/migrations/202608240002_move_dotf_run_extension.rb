class Dotfiles::Migration::MoveDotfRunExtension < Dotfiles::Migration
  VERSION = 202608240002

  def up
    global_extension_paths.each { |path| @system.rm_rf(path) }
  end

  def down
    raise NotImplementedError, "This migration moves dotf_run to the project and cannot be safely reversed."
  end

  private

  def global_extension_paths
    base = File.join(@home, ".pi", "agent", "extensions", "dotf_run")
    [base, "#{base}.ts"]
  end
end
