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

    def initialize(dotfiles_dir:, home:, system: SystemAdapter.new)
      @dotfiles_dir, @home, @system = dotfiles_dir, home, system
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
  end
end
