require "json"
require "pathname"
require "shellwords"

class Dotfiles::AgentLinkBackup
  include Dotfiles::AgentLinkPathState

  def initialize(home:, system:, macos:, executor:)
    @home = home
    @system = system
    @macos = macos
    @executor = executor
    @entries = []
    @seen_paths = {}
  end

  def create_source_dir(path)
    ensure_session!
    @system.mkdir_p(path)
    record_created(path, "dir")
  end

  def replace_target(source:, target:)
    ensure_session!
    path_exists?(target) ? backup_existing(target) : record_created(target, "symlink")
    @system.mkdir_p(File.dirname(target))
    @system.create_symlink(relative_link(source, target), target)
  end

  def finalize
    return unless @backup_dir

    manifest = {
      version: 1,
      createdAt: Time.now.utc.iso8601,
      scope: "global",
      operation: "sync-home-agent-links",
      entries: @entries
    }
    @system.write_file(File.join(@backup_dir, "manifest.json"), JSON.pretty_generate(manifest))
  end

  private

  def ensure_session!
    return if @backup_dir

    timestamp = Time.now.utc.iso8601.tr(":", "-")
    @backup_dir = File.join(@home, ".agents", "backup", timestamp)
    @system.mkdir_p(@backup_dir)
  end

  def backup_existing(path)
    return if seen?(path)

    backup_path = File.join(@backup_dir, relative_backup_path(path))
    kind = path_kind(path)
    @system.mkdir_p(File.dirname(backup_path))
    case kind
    when :symlink
      @system.create_symlink(@system.readlink(path), backup_path)
    when :dir
      @system.cp_r(path, backup_path)
    else
      @system.cp(path, backup_path)
    end
    unprotect(path)
    @system.rm_rf(path)
    @entries << {originalPath: path, backupPath: backup_path, kind: backup_kind(kind), action: "backup"}
    @seen_paths[path] = true
  end

  def unprotect(path)
    return unless @macos

    command = "sudo chflags -R nouchg,noschg #{Shellwords.shellescape(path)}"
    @executor.call(command, quiet: false)
  end

  def record_created(path, kind)
    return if seen?(path)

    @entries << {originalPath: path, kind: kind, action: "create"}
    @seen_paths[path] = true
  end

  def relative_link(source, target)
    Pathname.new(source).relative_path_from(Pathname.new(File.dirname(target))).to_s
  rescue ArgumentError
    source
  end

  def relative_backup_path(path)
    path.sub(%r{^/}, "")
  end

  def backup_kind(kind)
    {file: "file", dir: "dir", symlink: "symlink"}.fetch(kind)
  end

  def seen?(path)
    @seen_paths.key?(path)
  end
end
