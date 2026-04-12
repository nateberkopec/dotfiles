require "agent_link_sync"

class Dotfiles::Step::SyncAgentLinksStep < Dotfiles::Step
  def self.display_name
    "Agent Links"
  end

  def self.depends_on
    [Dotfiles::Step::InstallMiseToolsStep]
  end

  def should_run?
    syncer.needs_sync?
  end

  def run
    syncer.sync
  end

  def complete?
    super
    syncer.complete_errors.each { |error| add_error(error) }
    @errors.empty?
  end

  private

  def syncer
    Dotfiles::AgentLinkSync.new(
      home: @home,
      system: @system,
      clients: configured_clients,
      macos: @system.macos?,
      executor: method(:execute)
    )
  end

  def configured_clients
    Array(@config.fetch("dotagents_clients", Dotfiles::AgentLinkSync::DEFAULT_CLIENTS)).map(&:to_s)
  end
end
