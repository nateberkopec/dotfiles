class Dotfiles::Step::InstallMiseToolsStep < Dotfiles::Step
  DESCRIPTION = "Installs tools defined in mise configuration for the current platform.".freeze

  def self.depends_on
    [Dotfiles::Step::SyncHomeDirectoryStep]
  end

  def should_run?
    !mise_offline? && install_needed?
  end

  def run
    return unless managed_mise_config?
    return unless mise_available?

    @install_errors = {}
    @install_outputs = {}
    install_tools
    reset_cache
  end

  def complete?
    super
    return true unless managed_mise_config?

    unless mise_available?
      add_error("mise not available; cannot install mise tools")
      return false
    end

    install_errors.values.each { |message| add_error(message) }
    if ran? && install_errors.empty? && install_needed?
      add_error("mise reported success but tools are still missing; check `mise --cd ~ install --dry-run` and MISE_* env vars")
    end
    @errors.empty?
  end

  private

  def managed_mise_config?
    ci_tools.any? || @system.file_exist?(global_mise_config_path)
  end

  def ci_tools
    @ci_tools ||= ENV.fetch("MISE_CI_TOOLS", "").split(",").map(&:strip).reject(&:empty?)
  end

  def ordered_tools(tools)
    tools.each_with_index.sort_by { |(spec, index)| [tool_priority(spec), index] }.map(&:first)
  end

  def tool_priority(spec)
    return 2 if spec.start_with?("npm:")
    return 1 if spec.start_with?("cargo:")
    0
  end

  def install_tools
    output, status = execute(install_command)
    store_install_output("install", output)
    return if status == 0

    install_errors["install"] = format_command_error(install_command, status, output)
  end

  def install_errors
    @install_errors ||= {}
  end

  def store_install_output(spec, output)
    cleaned = output.to_s.strip.gsub(/\s+/, " ")
    return if cleaned.empty?

    @install_outputs[spec] = cleaned
    debug "mise output (#{spec}): #{cleaned}"
  end

  def mise_available?
    command_exists?("mise")
  end

  def mise_offline?
    ENV["MISE_OFFLINE"] == "1"
  end

  def install_needed?
    return false unless managed_mise_config?
    return true unless mise_available?

    output, status = execute(install_command(dry_run: true))
    return true unless status == 0

    output.to_s.lines.any? { |line| line.include?("would install") }
  end

  def reset_cache
    @install_errors = nil
    @install_outputs = nil
  end

  def global_mise_config_path
    File.join(@home, ".config", "mise", "config.toml")
  end

  def mise_command(*args)
    command("mise", "--cd", @home, *args)
  end

  def install_command(dry_run: false)
    args = ["install", "--yes"]
    args << "--dry-run" if dry_run
    args.concat(ordered_tools(ci_tools)) unless ci_tools.empty?
    mise_command(*args)
  end
end
