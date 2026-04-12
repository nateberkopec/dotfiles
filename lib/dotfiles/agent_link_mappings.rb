require "pathname"

class Dotfiles::AgentLinkMappings
  include Dotfiles::AgentLinkPathState

  DEFAULT_CLIENTS = %w[claude factory codex cursor opencode gemini].freeze

  def initialize(home:, system:, clients:)
    @home = home
    @system = system
    @clients = Array(clients)
  end

  def mappings
    file_mappings + command_mappings + hook_mappings + skill_mappings
  end

  def mapping_in_sync?(mapping)
    source_ready?(mapping) && target_symlink_matches?(mapping)
  end

  def mapping_error(mapping)
    return "Missing source: #{mapping[:source]}" unless source_ready?(mapping)
    return if target_symlink_matches?(mapping)

    "Link not in sync: #{mapping[:target]}"
  end

  def source_ready?(mapping)
    kind = path_kind(mapping[:source])
    return false unless kind
    return kind == :dir if mapping[:kind] == :dir

    kind == :file || kind == :symlink
  end

  private

  def file_mappings
    [
      ["claude", claude_source, home_target(".claude", "CLAUDE.md")],
      ["codex", agents_source, home_target(".codex", "AGENTS.md")],
      ["factory", agents_source, home_target(".factory", "AGENTS.md")],
      ["opencode", agents_source, home_target(".config", "opencode", "AGENTS.md")],
      ["gemini", gemini_source, home_target(".gemini", "GEMINI.md")]
    ].filter_map { |client, source, target| file_mapping(client, source, target) }
  end

  def command_mappings
    standard_directory_mappings(commands_source, "commands", codex_suffix: "prompts")
  end

  def hook_mappings
    [
      ["claude", home_target(".claude", "hooks")],
      ["factory", home_target(".factory", "hooks")]
    ].filter_map { |client, target| dir_mapping(client, hooks_source, target) }
  end

  def skill_mappings
    standard_directory_mappings(skills_source, "skills")
  end

  def standard_directory_mappings(source, suffix, codex_suffix: suffix)
    [
      ["claude", home_target(".claude", suffix)],
      ["codex", home_target(".codex", codex_suffix)],
      ["factory", home_target(".factory", suffix)],
      ["cursor", home_target(".cursor", suffix)],
      ["opencode", home_target(".config", "opencode", suffix)],
      ["gemini", home_target(".gemini", suffix)]
    ].filter_map { |client, target| dir_mapping(client, source, target) }
  end

  def file_mapping(client, source, target)
    return unless @clients.include?(client)
    {kind: :file, source: source, target: target}
  end

  def dir_mapping(client, source, target)
    return unless @clients.include?(client)
    {kind: :dir, source: source, target: target}
  end

  def agents_source
    File.join(agents_root, "AGENTS.md")
  end

  def claude_source
    preferred_source("CLAUDE.md")
  end

  def gemini_source
    preferred_source("GEMINI.md")
  end

  def commands_source
    File.join(agents_root, "commands")
  end

  def hooks_source
    File.join(agents_root, "hooks")
  end

  def skills_source
    File.join(agents_root, "skills")
  end

  def preferred_source(filename)
    preferred = File.join(agents_root, filename)
    path_exists?(preferred) ? preferred : agents_source
  end

  def agents_root
    File.join(@home, ".agents")
  end

  def home_target(*segments)
    File.join(@home, *segments)
  end

  def target_symlink_matches?(mapping)
    return false unless @system.symlink?(mapping[:target])

    target = @system.readlink(mapping[:target])
    resolve_link(mapping[:target], target) == File.expand_path(mapping[:source])
  rescue Errno::EINVAL
    false
  end

  def resolve_link(path, target)
    return File.expand_path(target) if Pathname.new(target).absolute?

    File.expand_path(target, File.dirname(path))
  end
end
