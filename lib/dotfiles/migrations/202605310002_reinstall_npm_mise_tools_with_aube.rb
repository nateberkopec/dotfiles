class Dotfiles::Migration::ReinstallNpmMiseToolsWithAube < Dotfiles::Migration
  VERSION = 202605310002

  MISE_TOOLS = [
    "npm:@openai/codex",
    "npm:@earendil-works/pi-coding-agent",
    "npm:@tobilu/qmd",
    "heroku"
  ].freeze

  def up
    return unless command_exists?("mise")

    install_aube
    MISE_TOOLS.each { |tool| reinstall_tool(tool) }
  end

  def down
    raise NotImplementedError, "This migration reinstalls tools and cannot be safely reversed."
  end

  private

  def install_aube
    execute(mise_command("install", "--yes", "aube"))
  end

  def reinstall_tool(tool)
    return unless tool_installed?(tool)

    execute(mise_command("uninstall", "--yes", tool))
    execute(aube_mise_command("install", "--yes", tool))
  end

  def tool_installed?(tool)
    command_succeeds?(mise_command("where", tool))
  end

  def aube_mise_command(*args)
    env_command({"MISE_NPM_PACKAGE_MANAGER" => "aube"}, *mise_command(*args))
  end

  def mise_command(*args)
    command("mise", "--cd", @home, *args)
  end
end
