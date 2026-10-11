require "digest"
require "fileutils"
require "json"
require "yaml"
require_relative "pruning/paths"
require_relative "pruning/hooks"
require_relative "pruning/ledger"

class AgentResourceLinks
  def initialize(root, home)
    @root, @home = root, home
    @package = File.join(home, ".pi/agent/git/github.com/nateberkopec/agent-stuff")
    @links = YAML.safe_load_file(File.join(root, "config/config.yml")).fetch("agent_resources")
    @baselines = JSON.parse(File.read(File.join(root, "config/agent_resource_baselines.json")))
  end

  def run
    validate_sources
    validate_destinations
    retire_copies
    ledger = ManagedPruning::Ledger.new(ManagedPruning::Paths.new(@home), ManagedPruning::Hooks.new)
    ledger.synchronize { transfer_links(ledger) }
  end

  private

  def validate_sources
    @links.each_value do |relative|
      source = File.join(@package, relative)
      raise "Agent package resource missing: #{source}" unless File.exist?(source)
    end
  end

  def validate_destinations
    @links.each_key do |relative|
      destination = File.join(@home, relative)
      next unless File.directory?(destination) && !File.symlink?(destination)

      raise "Refusing to replace a local agent resource directory: #{destination}"
    end
  end

  def retire_copies
    existing = @baselines.keys.select do |relative|
      destination = File.join(@home, relative)
      File.exist?(destination) && !package_link?(relative, destination)
    end
    modified = existing.reject { |relative| unchanged?(relative) }
    raise "Preserving modified extracted resources: #{modified.join(", ")}" unless modified.empty?

    existing.each { |relative| File.unlink(File.join(@home, relative)) }
  end

  def package_link?(relative, destination)
    source = @links[relative]
    source && File.symlink?(destination) && File.realpath(destination) == File.realpath(File.join(@package, source))
  end

  def unchanged?(relative)
    file = File.join(@home, relative)
    !File.symlink?(file) && File.file?(file) && Digest::SHA256.file(file).hexdigest == @baselines.fetch(relative)
  end

  def transfer_links(ledger)
    items = ledger.read
    @links.each do |relative, source|
      destination = File.join(@home, relative)
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.ln_sf(File.join(@package, source), destination)
      items.each_value { |item| item.fetch("files").delete(relative) }
    end
    items.delete_if { |_, item| item.fetch("files").empty? }
    ledger.write(items)
  end
end

AgentResourceLinks.new(ARGV.fetch(0), ARGV.fetch(1)).run
