require "shellwords"

class Dotfiles::Step::InstallMiseToolsStep < Dotfiles::Step
  def self.depends_on
    [Dotfiles::Step::SyncHomeDirectoryStep]
  end

  def should_run?
    !mise_offline? && install_needed?
  end

  def run
    return unless configured_tools?
    return unless mise_available?

    @install_errors = {}
    @install_outputs = {}
    install_tools
    reset_cache
  end

  def complete?
    super
    return true unless configured_tools?

    unless mise_available?
      add_error("mise not available; cannot install mise tools")
      return false
    end

    install_errors.values.each { |message| add_error(message) }
    if ran? && install_errors.empty? && install_needed?
      add_error("mise reported success but tools are still missing; check `mise install --dry-run` and MISE_* env vars for the global config path")
    end
    @errors.empty?
  end

  private

  def configured_tools
    @configured_tools ||= configured_tool_entries.filter_map do |entry|
      spec = entry.fetch(:spec)
      spec if platform_allowed?(entry[:platforms])
    end
  end

  def configured_tools?
    configured_tools.any?
  end

  def ordered_tools(tools)
    tools.each_with_index.sort_by { |(spec, index)| [tool_priority(spec), index] }.map(&:first)
  end

  def tool_priority(spec)
    return 2 if spec.start_with?("npm:")
    return 1 if spec.start_with?("cargo:")
    0
  end

  def configured_tool_entries
    raw = if ENV["MISE_CI_TOOLS"]
      ENV["MISE_CI_TOOLS"].split(",").map(&:strip)
    else
      @config.fetch("mise_tools", [])
    end
    Array(raw).filter_map { |entry| normalize_tool_entry(entry) }
  end

  def normalize_tool_entry(entry)
    case entry
    when String
      {spec: entry}
    when Hash
      spec = entry["tool"] || entry["spec"]
      return nil unless spec
      platforms = entry["platforms"]
      {spec: spec.to_s, platforms: Array(platforms).map(&:to_s)}
    end
  end

  def platform_allowed?(platforms)
    return true if platforms.nil? || platforms.empty?
    platforms.any? { |platform| platform_match?(platform) }
  end

  def platform_match?(platform)
    case platform
    when "macos", "darwin", "mac"
      @system.macos?
    when "linux"
      @system.linux?
    when "debian"
      @system.debian?
    else
      false
    end
  end

  def install_tools
    output, status = execute(install_command)
    store_install_output("install", output)
    return if status == 0

    install_errors["install"] = format_install_error(install_command, status, output)
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

  def format_install_error(command, status, output)
    cleaned = output.to_s.strip.gsub(/\s+/, " ")
    return "#{command} failed (status #{status})" if cleaned.empty?
    "#{command} failed (status #{status}): #{cleaned}"
  end

  def mise_available?
    command_exists?("mise")
  end

  def mise_offline?
    ENV["MISE_OFFLINE"] == "1"
  end

  def install_needed?
    return false unless configured_tools?
    return true unless mise_available?

    output, status = execute(install_command(dry_run: true))
    return true unless status == 0

    output.to_s.lines.any? { |line| line.include?("would install") }
  end

  def reset_cache
    @install_errors = nil
    @install_outputs = nil
  end

  def mise_command
    "mise --cd #{Shellwords.shellescape(@home)}"
  end

  def install_command(dry_run: false)
    specs = ordered_tools(configured_tools)
    command = "#{mise_command} install --yes"
    command = "#{command} --dry-run" if dry_run
    return command if specs.empty?

    "#{command} #{specs.join(" ")}"
  end
end
