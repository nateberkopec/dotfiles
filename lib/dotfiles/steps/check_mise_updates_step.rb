require "shellwords"

class Dotfiles::Step::CheckMiseUpdatesStep < Dotfiles::Step
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
    execute("#{mise_command} cache clear")
    execute("#{mise_command} plugins update")
    output, = execute("#{mise_command} outdated --bump --no-header")
    tools = output.lines.map(&:strip).reject(&:empty?)
    return if tools.empty?

    add_notice(
      title: "🛠️ Mise Updates Available",
      message: "#{tools.count} tool(s) have updates available.\n\nRun 'mise-check-updates' to refresh and review updates."
    )
  end

  def mise_available?
    command_exists?("mise")
  end

  def mise_offline?
    ENV["MISE_OFFLINE"] == "1"
  end

  def mise_command
    "mise --cd #{Shellwords.shellescape(@home)}"
  end
end
