class Dotfiles
  class Migration
    @@migrations = []

    def self.inherited(subclass)
      @@migrations << subclass
    end

    def self.all_migrations
      @@migrations.sort_by(&:version)
    end

    def self.version
      const_get(:VERSION, false)
    end

    def self.display_name
      name.gsub(/^Dotfiles::Migration::/, "").gsub(/([A-Z]+)([A-Z][a-z])/, '\\1 \\2').gsub(/([a-z\d])([A-Z])/, '\\1 \\2')
    end

    def self.macos_only
      @macos_only = true
    end

    def self.macos_only?
      @macos_only || false
    end

    def self.debian_only
      @debian_only = true
    end

    def self.debian_only?
      @debian_only || false
    end

    def initialize(debug:, dotfiles_repo:, dotfiles_dir:, home:, system: SystemAdapter.new)
      @debug, @dotfiles_repo, @dotfiles_dir, @home, @system = debug, dotfiles_repo, dotfiles_dir, home, system
      @config = Config.new(dotfiles_dir, system: system)
    end

    def allowed_on_platform?
      platform_requirement_met?(:macos) && platform_requirement_met?(:debian)
    end

    def up
      raise NotImplementedError, "Subclasses must implement #up"
    end

    def down
      raise NotImplementedError, "Subclasses must implement #down"
    end

    private

    def execute(command, quiet: true)
      @system.execute(command, quiet: quiet)
    end

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

    def platform_requirement_met?(platform)
      predicate = "#{platform}_only?"
      !self.class.public_send(predicate) || @system.public_send("#{platform}?")
    end

    def command_exists?(command)
      command_succeeds?(shell_script('command -v -- "$1" >/dev/null 2>&1', command))
    end
  end
end
