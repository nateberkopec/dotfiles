require "pathname"
require "shellwords"
require "agent_link_mappings"

class Dotfiles::Step::SyncAgentLinksStep < Dotfiles::Step
  def self.display_name
    "Agent Links"
  end

  def self.depends_on
    [Dotfiles::Step::InstallMiseToolsStep]
  end

  def should_run?
    mappings.any? { |mapping| !mapping_in_sync?(mapping) }
  end

  def run
    mappings.each do |mapping|
      next unless ensure_source_ready(mapping)
      next if mapping_in_sync?(mapping)

      replace_target(mapping)
    end
  end

  def complete?
    super
    complete_errors.each { |error| add_error(error) }
    @errors.empty?
  end

  private

  def complete_errors
    mappings.filter_map { |mapping| agent_link_mappings.mapping_error(mapping) }
  end

  def ensure_source_ready(mapping)
    return true if agent_link_mappings.source_ready?(mapping)
    return false if mapping[:kind] == :file

    @system.mkdir_p(mapping[:source])
    true
  end

  def replace_target(mapping)
    remove_target(mapping[:target]) if path_exists?(mapping[:target])
    @system.mkdir_p(File.dirname(mapping[:target]))
    @system.create_symlink(relative_link(mapping[:source], mapping[:target]), mapping[:target])
  end

  def remove_target(path)
    unprotect(path)
    @system.rm_rf(path)
  end

  def unprotect(path)
    return unless @system.macos?

    execute("sudo chflags -R nouchg,noschg #{Shellwords.shellescape(path)}", quiet: false)
  end

  def relative_link(source, target)
    Pathname.new(source).relative_path_from(Pathname.new(File.dirname(target))).to_s
  rescue ArgumentError
    source
  end

  def path_exists?(path)
    @system.symlink?(path) || @system.dir_exist?(path) || @system.file_exist?(path)
  end

  def mappings
    agent_link_mappings.mappings
  end

  def mapping_in_sync?(mapping)
    agent_link_mappings.mapping_in_sync?(mapping)
  end

  def agent_link_mappings
    @agent_link_mappings ||= Dotfiles::AgentLinkMappings.new(home: @home, system: @system, clients: configured_clients)
  end

  def configured_clients
    Array(@config.fetch("dotagents_clients", Dotfiles::AgentLinkMappings::DEFAULT_CLIENTS)).map(&:to_s)
  end
end
