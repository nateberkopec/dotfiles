require "pathname"

class Dotfiles::Step::SyncAgentLinksStep < Dotfiles::Step
  DEFAULT_CLIENTS = %w[claude factory codex cursor opencode gemini].freeze
  AGENT_FILE_TARGETS = {
    "factory" => %w[.factory AGENTS.md],
    "codex" => %w[.codex AGENTS.md],
    "opencode" => %w[.config opencode AGENTS.md],
    "ampcode" => %w[.config amp AGENTS.md]
  }.freeze
  COMMAND_TARGETS = {
    "claude" => %w[.claude commands],
    "factory" => %w[.factory commands],
    "codex" => %w[.codex prompts],
    "opencode" => %w[.config opencode commands],
    "cursor" => %w[.cursor commands],
    "gemini" => %w[.gemini commands]
  }.freeze
  HOOK_TARGETS = {
    "claude" => %w[.claude hooks],
    "factory" => %w[.factory hooks]
  }.freeze
  SKILL_TARGETS = {
    "claude" => %w[.claude skills],
    "factory" => %w[.factory skills],
    "codex" => %w[.codex skills],
    "opencode" => %w[.config opencode skills],
    "cursor" => %w[.cursor skills],
    "gemini" => %w[.gemini skills],
    "github" => %w[.copilot skills]
  }.freeze

  def self.display_name
    "Agent Links"
  end

  def self.depends_on
    [Dotfiles::Step::InstallMiseToolsStep]
  end

  def should_run?
    configured_clients.any? && agents_root_exists? && !complete?
  end

  def run
    link_mappings.each { |mapping| sync_mapping(mapping) }
  end

  def complete?
    super
    return true if configured_clients.empty?

    add_error("Missing ~/.agents; sync home directory first") unless agents_root_exists?
    return false unless @errors.empty?

    out_of_sync_mappings.each do |mapping|
      add_error("Agent link not in sync: #{collapse_path_to_home(mapping[:target])}")
    end
    @errors.empty?
  end

  private

  def agents_root_exists?
    @system.dir_exist?(agents_root)
  end

  def agents_root
    File.join(@home, ".agents")
  end

  def out_of_sync_mappings
    link_mappings.reject { |mapping| link_in_sync?(mapping) }
  end

  def link_mappings
    [
      *instruction_file_mappings,
      *agent_file_mappings,
      *command_mappings,
      *hook_mappings,
      *skill_mappings
    ]
  end

  def instruction_file_mappings
    {
      "claude" => {
        source: first_existing_file_source("CLAUDE.md", "AGENTS.md"),
        target: File.join(@home, ".claude", "CLAUDE.md")
      },
      "gemini" => {
        source: first_existing_file_source("GEMINI.md", "AGENTS.md"),
        target: File.join(@home, ".gemini", "GEMINI.md")
      }
    }.filter_map do |client, entry|
      mapping(entry[:source], entry[:target], kind: :file) if configured_for?(client) && entry[:source]
    end
  end

  def agent_file_mappings
    source = file_source("AGENTS.md")
    source ? mappings_for(source, AGENT_FILE_TARGETS) : []
  end

  def command_mappings
    source = dir_source("commands")
    source ? mappings_for(source, COMMAND_TARGETS) : []
  end

  def hook_mappings
    source = dir_source("hooks")
    source ? mappings_for(source, HOOK_TARGETS) : []
  end

  def skill_mappings
    source = dir_source("skills")
    source ? mappings_for(source, SKILL_TARGETS) : []
  end

  def file_source(name)
    path = File.join(agents_root, name)
    @system.file_exist?(path) ? path : nil
  end

  def dir_source(name)
    path = File.join(agents_root, name)
    @system.dir_exist?(path) ? path : nil
  end

  def first_existing_file_source(*names)
    names.map { |name| file_source(name) }.find(&:itself)
  end

  def mapping(source, target, kind: :dir)
    {source: source, target: target, kind: kind}
  end

  def mappings_for(source, target_map)
    target_map.filter_map do |client, path_parts|
      mapping(source, File.join(@home, *path_parts), kind: :dir) if configured_for?(client)
    end
  end

  def configured_for?(client)
    configured_clients.include?(client)
  end

  def link_in_sync?(mapping)
    target = mapping[:target]

    if @system.symlink?(target)
      return resolved_link_target(target) == File.expand_path(mapping[:source])
    end

    mapping[:kind] == :dir && @system.dir_exist?(target)
  end

  def resolved_link_target(target)
    File.expand_path(@system.readlink(target), File.dirname(target))
  end

  def sync_mapping(mapping)
    target = mapping[:target]
    return if link_in_sync?(mapping)
    return if mapping[:kind] == :dir && @system.dir_exist?(target)

    @system.mkdir_p(File.dirname(target))
    @system.rm_rf(target) if target_exists?(target)
    @system.create_symlink(relative_link_target(mapping[:source], target), target)
  end

  def target_exists?(target)
    @system.file_exist?(target) || @system.dir_exist?(target) || @system.symlink?(target)
  end

  def relative_link_target(source, target)
    source_path = Pathname.new(File.expand_path(source))
    target_dir = Pathname.new(File.expand_path(File.dirname(target)))
    relative = source_path.relative_path_from(target_dir).to_s
    resolved_relative = File.expand_path(relative, File.dirname(target))
    (resolved_relative == File.expand_path(source)) ? relative : File.expand_path(source)
  rescue ArgumentError
    File.expand_path(source)
  end

  def configured_clients
    Array(@config.fetch("dotagents_clients", DEFAULT_CLIENTS)).map(&:to_s)
  end
end
