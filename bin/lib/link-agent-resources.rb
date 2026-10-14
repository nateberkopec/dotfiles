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
    ledger = ManagedPruning::Ledger.new(ManagedPruning::Paths.new(@home), ManagedPruning::Hooks.new)
    ledger.synchronize do
      items = ledger.read
      retire_copies(items)
      transfer_links(ledger, items)
    end
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

  def retire_copies(items)
    existing = @baselines.keys.select do |relative|
      destination = File.join(@home, relative)
      File.exist?(destination) && !package_link?(relative, destination)
    end
    modified = existing.reject { |relative| unchanged?(relative, items) }
    raise "Preserving modified extracted resources: #{modified.join(", ")}" unless modified.empty?

    existing.each { |relative| File.unlink(File.join(@home, relative)) }
  end

  def package_link?(relative, destination)
    source = @links[relative]
    source && File.symlink?(destination) && File.realpath(destination) == File.realpath(File.join(@package, source))
  end

  def unchanged?(relative, items)
    file = File.join(@home, relative)
    return false if File.symlink?(file) || !File.file?(file)

    digest = Digest::SHA256.file(file).hexdigest
    recorded = items.values.filter_map { |item| item.fetch("files")[relative] }
    @baselines.fetch(relative).include?(digest) || recorded.any? { |entry| entry["type"] == "file" && entry["sha256"] == digest }
  end

  def transfer_links(ledger, items)
    @links.each do |relative, source|
      destination = File.join(@home, relative)
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.ln_s(File.join(@package, source), destination, force: true, target_directory: false)
      items.each_value { |item| item.fetch("files").delete(relative) }
    end
    items.delete_if { |_, item| item.fetch("files").empty? }
    ledger.write(items)
  end
end

AgentResourceLinks.new(ARGV.fetch(0), ARGV.fetch(1)).run
