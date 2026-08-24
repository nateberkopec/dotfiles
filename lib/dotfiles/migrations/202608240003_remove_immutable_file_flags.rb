class Dotfiles::Migration::RemoveImmutableFileFlags < Dotfiles::Migration
  VERSION = 202608240003
  MANAGED_PATHS = %w[
    .aws/credentials
    .gem/credentials
    .git-hooks/pre-commit
    .git-hooks/pre-push
    .pi/agent/extensions/find_timeout.ts
  ].freeze

  macos_only

  def up
    files = managed_files.select { |file| @system.file_exist?(file) }
    return if files.empty?

    execute(command("sudo", "chflags", "noschg,nouchg", *files))
  end

  def down
    raise NotImplementedError, "This migration removes obsolete immutable flags and cannot be safely reversed."
  end

  private

  def managed_files
    MANAGED_PATHS.map { |path| File.join(@home, path) }
  end
end
