class Dotfiles
  # Shared command-construction and execution helpers used by both
  # Dotfiles::Step and Dotfiles::Migration. The includer must provide
  # `@system` (an object responding to #execute, like SystemAdapter).
  module CommandHelpers
    def command(*parts)
      Dotfiles::Command.argv(*parts)
    end

    def env_command(vars, *parts)
      Dotfiles::Command.env(vars, *parts)
    end

    def shell_script(script, *args)
      command("bash", "-c", script, "dotfiles", *args)
    end

    def command_succeeds?(command)
      _, status = @system.execute(command)
      status == 0
    end

    def command_exists?(command)
      command_succeeds?(shell_script('command -v -- "$1" >/dev/null 2>&1', command))
    end
  end
end
