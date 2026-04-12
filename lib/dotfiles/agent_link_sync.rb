require "agent_link_path_state"
require "agent_link_backup"
require "agent_link_mappings"

class Dotfiles::AgentLinkSync
  DEFAULT_CLIENTS = Dotfiles::AgentLinkMappings::DEFAULT_CLIENTS

  def initialize(home:, system:, clients:, macos:, executor:)
    @mappings = Dotfiles::AgentLinkMappings.new(home: home, system: system, clients: clients)
    @backup = Dotfiles::AgentLinkBackup.new(home: home, system: system, macos: macos, executor: executor)
  end

  def needs_sync?
    mappings.any? { |mapping| !@mappings.mapping_in_sync?(mapping) }
  end

  def complete_errors
    mappings.filter_map { |mapping| @mappings.mapping_error(mapping) }
  end

  def sync
    mappings.each do |mapping|
      unless @mappings.source_ready?(mapping)
        next if mapping[:kind] == :file

        @backup.create_source_dir(mapping[:source])
      end
      next if @mappings.mapping_in_sync?(mapping)

      @backup.replace_target(source: mapping[:source], target: mapping[:target])
    end
    @backup.finalize
  end

  private

  def mappings
    @mappings.mappings
  end
end
