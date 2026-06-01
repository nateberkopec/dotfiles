class Dotfiles::Migration::UninstallRemovedNpmSearchTool < Dotfiles::Migration
  VERSION = 202606020001

  TOOL = "npm:@#{%w[to bi lu].join}/#{%w[q md].join}".freeze

  def up
    return unless command_exists?("mise")
    return unless tool_installed?

    execute(mise_command("uninstall", "--yes", TOOL))
  end

  def down
    raise NotImplementedError, "This migration uninstalls a removed tool and cannot be safely reversed."
  end

  private

  def tool_installed?
    command_succeeds?(mise_command("where", TOOL))
  end

  def mise_command(*args)
    command("mise", "--cd", @home, *args)
  end
end
