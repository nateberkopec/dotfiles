require "json"

class Dotfiles::Step::CheckMiseUpdatesStep < Dotfiles::Step
  DESCRIPTION = "Checks mise plugins and tools for available updates and reports them.".freeze

  def self.depends_on
    [Dotfiles::Step::InstallMiseToolsStep]
  end

  def should_run?
    return false if mise_offline?
    return false unless mise_available?

    check_outdated_tools
    false
  end

  def complete?
    super
    true
  end

  private

  def check_outdated_tools
    execute(mise_command("cache", "clear"))
    execute(mise_command("plugins", "update"))
    output, status = execute(mise_command("outdated", "--json"))
    return unless status == 0

    tools = actionable_outdated_tools(output)
    return if tools.empty?

    add_notice(
      title: "🛠️ Mise Updates Available",
      message: "#{tools.count} tool(s) have updates available.\n\nRun 'mise-check-updates' to refresh and review updates."
    )
  end

  def actionable_outdated_tools(output)
    JSON.parse(output).values.select { |tool| actionable_tool?(tool) }
  rescue JSON::ParserError
    []
  end

  def actionable_tool?(tool)
    requested = tool["requested"].to_s
    current = tool["current"].to_s
    latest = tool["latest"].to_s

    semantic_version?(requested) && semantic_version?(current) && semantic_version?(latest) && current != latest
  end

  def semantic_version?(value)
    value.match?(/^v?\d+(?:\.\d+)*(?:[-+][0-9A-Za-z.-]+)?$/)
  end

  def mise_available?
    command_exists?("mise")
  end

  def mise_offline?
    ENV["MISE_OFFLINE"] == "1"
  end

  def mise_command(*args)
    command("mise", "--cd", @home, *args)
  end
end
