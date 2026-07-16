class Dotfiles::Step::ClearMiseCacheStep < Dotfiles::Step
  DESCRIPTION = "Clears mise metadata cache before installing managed tools.".freeze

  def self.depends_on
    [Dotfiles::Step::SyncHomeDirectoryStep]
  end

  def should_run?
    mise_available? && !mise_offline? && install_needed?
  end

  def run
    output, status = execute(clear_cache_command)
    @error = format_command_error(clear_cache_command, status, output) unless status == 0
  end

  def complete?
    super
    add_error(@error) if @error
    @errors.empty?
  end

  private

  def install_needed?
    return false unless managed_mise_config?

    output, status = execute(install_check_command)
    return true unless status == 0

    output.to_s.lines.any? { |line| line.include?("would install") }
  end

  def managed_mise_config?
    ci_tools.any? || @system.file_exist?(global_mise_config_path)
  end

  def ci_tools
    ENV.fetch("MISE_CI_TOOLS", "").split(",").map(&:strip).reject(&:empty?)
  end

  def install_check_command
    args = ["--cd", @home, "install", "--yes", "--dry-run"]
    args.concat(ci_tools) unless ci_tools.empty?
    command("mise", *args)
  end

  def clear_cache_command
    command("mise", "cache", "clear", "--yes")
  end

  def global_mise_config_path
    File.join(@home, ".config", "mise", "config.toml")
  end

  def mise_available?
    command_exists?("mise")
  end

  def mise_offline?
    ENV["MISE_OFFLINE"] == "1"
  end
end
