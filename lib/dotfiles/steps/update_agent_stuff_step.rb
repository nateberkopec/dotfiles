class Dotfiles::Step::UpdateAgentStuffStep < Dotfiles::Step
  DESCRIPTION = "Refreshes trusted agent-stuff resources from main.".freeze
  SOURCE = "git:github.com/nateberkopec/agent-stuff@main".freeze

  def self.depends_on
    [Dotfiles::Step::InstallPiPackagesStep]
  end

  def should_run?
    true
  end

  def run
    invocation = command("pi", "update", SOURCE)
    output, status = execute(invocation)
    @update_error = format_command_error(invocation, status, output) unless status == 0
    return if @update_error

    checkout = File.join(@home, ".pi/agent/git/github.com/nateberkopec/agent-stuff")
    revision, status = execute(command("git", "-C", checkout, "rev-parse", "HEAD"))
    if status == 0
      add_notice(title: "Agent resources", message: "agent-stuff main at #{revision.strip}")
    else
      @update_error = "Cannot determine installed agent-stuff revision: #{revision.strip}"
    end
  end

  def complete?
    super
    add_error(@update_error) if @update_error
    @errors.empty?
  end
end
