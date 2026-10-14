class Dotfiles::Step::LinkAgentResourcesStep < Dotfiles::Step
  DESCRIPTION = "Links shared agent resources from the refreshed Pi package.".freeze

  def self.depends_on
    [Dotfiles::Step::UpdateAgentStuffStep]
  end

  def should_run?
    links.any? && (retired_copies? || !links.all? { |target, source| linked?(target, source) })
  end

  def run
    invocation = command("ruby", File.join(@dotfiles_dir, "bin/lib/link-agent-resources.rb"), @dotfiles_dir, @home)
    output, status = execute(invocation)
    @link_error = format_command_error(invocation, status, output) unless status == 0
  end

  def complete?
    super
    add_error(@link_error) if @link_error
    links.each do |target, source|
      add_error("Agent resource not linked: #{target}") unless linked?(target, source)
    end
    add_error("Extracted agent resources remain in their old locations") if retired_copies?
    @errors.empty?
  end

  private

  def links
    @config.fetch("agent_resources", {}).to_h do |target, source|
      [File.join(@home, target), File.join(package_root, source)]
    end
  end

  def package_root
    File.join(@home, ".pi/agent/git/github.com/nateberkopec/agent-stuff")
  end

  def linked?(target, source)
    @system.file_exist?(source) && @system.symlink?(target) && @system.realpath(target) == @system.realpath(source)
  rescue Errno::ENOENT
    false
  end

  def retired_copies?
    path = File.join(@dotfiles_dir, "config/agent_resource_baselines.json")
    return false unless @system.file_exist?(path)

    JSON.parse(@system.read_file(path)).keys.any? do |relative|
      target = File.join(@home, relative)
      source = links[target]
      @system.file_exist?(target) && (!source || !linked?(target, source))
    end
  end
end
