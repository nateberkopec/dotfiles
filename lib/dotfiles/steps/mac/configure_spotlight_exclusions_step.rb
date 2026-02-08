require "shellwords"

class Dotfiles::Step::ConfigureSpotlightExclusionsStep < Dotfiles::Step
  prepend Dotfiles::Step::Sudoable

  macos_only

  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep]
  end

  def should_run?
    disabled_volumes.any? && !all_volumes_excluded?
  end

  def run
    disabled_volumes.each do |volume|
      if volume_root?(volume)
        next if indexing_disabled?(volume)
        execute("mdutil -i off #{shell_escape(volume)}", sudo: true)
      else
        ensure_metadata_never_index(volume)
      end
    end
  end

  def complete?
    super
    return true unless disabled_volumes.any?

    disabled_volumes.each { |volume| check_disabled_volume(volume) }
    @errors.empty?
  end

  private

  def all_volumes_excluded?
    disabled_volumes.all? { |volume| volume_excluded?(volume) }
  end

  def volume_excluded?(volume)
    if volume_root?(volume)
      indexing_disabled?(volume)
    else
      !@system.dir_exist?(volume) || metadata_never_index_exists?(volume)
    end
  end

  def check_disabled_volume(volume)
    if volume_root?(volume)
      add_error("Spotlight indexing still enabled for #{volume}") unless indexing_disabled?(volume)
      return
    end

    unless @system.dir_exist?(volume)
      add_error("Spotlight exclusion directory missing: #{volume}")
      return
    end
    add_error("Spotlight exclusion file missing for #{volume}") unless metadata_never_index_exists?(volume)
  end

  def indexing_disabled?(volume)
    output, status = execute("mdutil -s #{shell_escape(volume)}", quiet: true)
    return false unless status == 0
    output.downcase.include?("disabled")
  end

  def ensure_metadata_never_index(path)
    return if metadata_never_index_exists?(path)
    return unless @system.dir_exist?(path)
    @system.write_file(metadata_never_index_path(path), "")
  end

  def metadata_never_index_exists?(path)
    @system.file_exist?(metadata_never_index_path(path))
  end

  def metadata_never_index_path(path)
    File.join(path, ".metadata_never_index")
  end

  def disabled_volumes
    @disabled_volumes ||= normalize_volumes(spotlight_settings.fetch("disabled_volumes", []))
  end

  def spotlight_settings
    @spotlight_settings ||= @config.fetch("spotlight_settings", {})
  end

  def normalize_volumes(volumes)
    Array(volumes).compact.map { |volume| expand_path_with_home(volume) }.uniq
  end

  def volume_root?(path)
    mount_point_for(path) == path
  end

  def mount_point_for(path)
    output, status = execute("df -P #{shell_escape(path)}", quiet: true)
    return nil unless status == 0
    lines = output.split("\n")
    return nil if lines.length < 2
    lines.last.split(/\s+/).last
  end

  def shell_escape(value)
    Shellwords.escape(value)
  end
end
