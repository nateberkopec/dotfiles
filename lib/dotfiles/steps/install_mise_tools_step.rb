require "json"
require "shellwords"

class Dotfiles::Step::InstallMiseToolsStep < Dotfiles::Step
  def self.depends_on
    [Dotfiles::Step::SyncHomeDirectoryStep]
  end

  def should_run?
    return false unless configured_tools?
    return true unless mise_available?
    !missing_tools.empty?
  end

  def run
    return unless configured_tools?
    return unless mise_available?

    @install_errors = {}
    @install_outputs = {}
    ordered_tools(missing_tools).each { |spec| install_tool(spec) }
    reset_cache
  end

  def complete?
    super
    return true unless configured_tools?

    unless mise_available?
      add_error("mise not available; cannot install mise tools")
      return false
    end

    add_error(@installed_tools_error) if @installed_tools_error
    install_errors.values.each { |message| add_error(message) }
    if ran? && install_errors.empty? && missing_tools.any?
      add_error("mise reported success but tools are still missing; check `mise config ls --json` and MISE_* env vars for the global config path")
    end
    missing_tools.each { |spec| add_error("mise tool not installed: #{spec}") }
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
    raw = @config.fetch("mise_tools", [])
    Array(raw).filter_map { |entry| normalize_tool_entry(entry) }
  end

  def normalize_tool_entry(entry)
    case entry
    when String
      {spec: entry}
    when Hash
      spec = entry["tool"] || entry[:tool] || entry["spec"] || entry[:spec]
      return nil unless spec
      platforms = entry["platforms"] || entry[:platforms]
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

  def install_tool(spec)
    output, status = execute("#{mise_command} install --yes #{spec}")
    store_install_output(spec, output)
    return if status == 0

    install_errors[spec] = format_install_error(spec, status, output)
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

  def format_install_error(spec, status, output)
    cleaned = output.to_s.strip.gsub(/\s+/, " ")
    return "mise install --yes #{spec} failed (status #{status})" if cleaned.empty?
    "mise install --yes #{spec} failed (status #{status}): #{cleaned}"
  end

  def mise_available?
    command_exists?("mise")
  end

  def missing_tools
    @missing_tools ||= begin
      return configured_tools unless mise_available?
      installed = installed_tools
      configured_tools.reject { |spec| tool_configured?(installed, spec) }
    end
  end

  def installed_tools
    return @installed_tools if installed_tools_cached?

    output, status = execute("#{mise_command} ls --installed --json")
    return record_installed_tools_error("mise ls --installed --json failed (status #{status})") unless status == 0

    parse_installed_tools(output)
  end

  def installed_tools_cached?
    instance_variable_defined?(:@installed_tools) && !@installed_tools.nil?
  end

  def parse_installed_tools(output)
    parsed = JSON.parse(output)
    @installed_tools = normalize_installed_tools(parsed)
  rescue JSON::ParserError => e
    record_installed_tools_error("mise ls --installed --json parse failed: #{e.message}")
  end

  def normalize_installed_tools(parsed)
    return {} if parsed.nil?
    return parsed if parsed.is_a?(Hash)
    return normalize_installed_tool_entries(parsed) if parsed.is_a?(Array)

    record_installed_tools_error("mise ls --installed --json returned unsupported JSON: #{parsed.class}")
    {}
  end

  def normalize_installed_tool_entries(entries)
    entries.each_with_object({}) do |entry, acc|
      key, value = normalize_installed_tool_entry(entry)
      acc[key] = value if key
    end
  end

  def normalize_installed_tool_entry(entry)
    case entry
    when String
      [entry, true]
    when Hash
      key = installed_tool_key(entry)
      [key, entry] if key
    end
  end

  def installed_tool_key(entry)
    entry["tool"] || entry[:tool] || entry["spec"] || entry[:spec] || entry["name"] || entry[:name]
  end

  def record_installed_tools_error(message)
    @installed_tools_error = message
    @installed_tools = {}
  end

  def tool_configured?(installed, spec)
    installed.key?(tool_key(spec))
  end

  def tool_key(spec)
    base = spec.split("[", 2).first
    return base if base.nil?

    if base.start_with?("npm:")
      return base if base.count("@") == 1
      return strip_version(base)
    end

    return strip_version(base) if base.include?("@")
    base
  end

  def strip_version(base)
    head, sep, = base.rpartition("@")
    sep.empty? ? base : head
  end

  def reset_cache
    @installed_tools = nil
    @missing_tools = nil
    @installed_tools_error = nil
  end

  def mise_command
    "mise --cd #{Shellwords.shellescape(@home)}"
  end
end
