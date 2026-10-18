class Dotfiles::Migration::RepairOmniWMDirectoryPermissions < Dotfiles::Migration
  VERSION = 202610180001

  macos_only

  def up
    data = ENV.fetch("MISE_DATA_DIR", File.join(@home, ".local/share/mise"))
    installs = ENV.fetch("MISE_INSTALLS_DIR", File.join(data, "installs"))
    root = File.join(installs, "github-barut-srb-omni-wm/0.7.2")
    return unless @system.dir_exist?(root) && !@system.symlink?(root)

    @system.find_files(root) do |path|
      stat = @system.lstat(path)
      next unless stat.directory? && stat.uid == Process.uid

      @system.chmod(stat.mode | 0o700, path)
    end
  end

  def down
    raise NotImplementedError, "This migration repairs legacy directory permissions and cannot be safely reversed."
  end
end
