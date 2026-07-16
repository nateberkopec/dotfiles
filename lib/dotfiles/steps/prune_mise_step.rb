class Dotfiles::Step::PruneMiseStep < Dotfiles::Step
  DESCRIPTION = "Prunes old mise installs and cache entries after managed tools are installed.".freeze

  def self.depends_on
    [Dotfiles::Step::InstallMiseToolsStep, Dotfiles::Step::InstallPiPackagesStep]
  end

  def should_run?
    mise_available? && !mise_offline? && ci_tools.empty? && prune_needed?
  end

  def run
    @errors_from_commands = []
    prune_commands.each { |prune_command| run_prune_command(prune_command) }
  end

  def complete?
    super
    errors_from_commands.each { |message| add_error(message) }
    @errors.empty?
  end

  private

  def prune_needed?
    prunable_tools? || prunable_cache?
  end

  def prunable_tools?
    _output, status = execute(command("mise", "prune", "--dry-run-code", "--yes"))
    status != 0
  end

  def prunable_cache?
    output, status = execute(command("mise", "cache", "prune", "--dry-run", "--verbose"))
    status == 0 && !output.to_s.strip.empty?
  end

  def run_prune_command(prune_command)
    output, status = execute(prune_command)
    errors_from_commands << format_command_error(prune_command, status, output) unless status == 0
  end

  def prune_commands
    [
      command("mise", "prune", "--yes"),
      command("mise", "cache", "prune", "--yes")
    ]
  end

  def errors_from_commands
    @errors_from_commands ||= []
  end

  def ci_tools
    ENV.fetch("MISE_CI_TOOLS", "")
  end

  def mise_available?
    command_exists?("mise")
  end

  def mise_offline?
    ENV["MISE_OFFLINE"] == "1"
  end
end
