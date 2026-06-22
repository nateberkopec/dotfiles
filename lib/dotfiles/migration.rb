class Dotfiles
  class Migration
    @@migrations = []

    extend Dotfiles::PlatformRestrictable
    include Dotfiles::CommandHelpers

    private :command, :env_command, :shell_script, :command_succeeds?, :command_exists?

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

    def initialize(debug:, dotfiles_repo:, dotfiles_dir:, home:, system: SystemAdapter.new, config: nil)
      @debug, @dotfiles_repo, @dotfiles_dir, @home, @system = debug, dotfiles_repo, dotfiles_dir, home, system
      @config = config || Config.new(dotfiles_dir, system: system)
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
      @system.execute!(command, quiet: quiet)
    end

    def platform_requirement_met?(platform)
      predicate = "#{platform}_only?"
      !self.class.public_send(predicate) || @system.public_send("#{platform}?")
    end
  end
end
