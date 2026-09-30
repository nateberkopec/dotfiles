class Dotfiles::Migration::RemoveImmutableFileFlags < Dotfiles::Migration
  VERSION = 202608240003
  MANAGED_PATHS = %w[
    .aws/credentials
    .gem/credentials
    .pi/agent/extensions/find_timeout.ts
  ].freeze

  macos_only

  def up
    files = managed_files.select { |file| @system.file_exist?(file) }
    return if files.empty?

    files.each do |file|
      flags_command = command("chflags", "noschg,nouchg", file)
      _, status = @system.execute(flags_command)
      execute(command("sudo", "chflags", "noschg,nouchg", file)) unless status == 0
    end
  end

  def down
    raise NotImplementedError, "This migration removes obsolete immutable flags and cannot be safely reversed."
  end

  private

  def managed_files
    MANAGED_PATHS.map { |path| File.join(@home, path) }
  end
end
