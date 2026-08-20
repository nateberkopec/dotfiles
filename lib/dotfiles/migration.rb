class Dotfiles
  class Migration
    HOMEBREW_ENV = {
      "HOMEBREW_NO_AUTO_UPDATE" => "1",
      "HOMEBREW_NO_ENV_HINTS" => "1"
    }.freeze

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

    def remove_homebrew_formula(name)
      return unless command_exists?("brew")
      return unless command_succeeds?(homebrew_command("list", "--formula", name))

      execute(homebrew_command("uninstall", name))
    end

    def remove_apt_package(name, files: [])
      return unless @system.debian?

      execute(command("sudo", "apt-get", "remove", "--yes", name)) if command_succeeds?(command("dpkg-query", "--show", name))
      existing_files = files.select { |path| @system.file_exist?(path) }
      execute(shell_script('sudo rm -f "$@"', *existing_files)) unless existing_files.empty?
    end

    def homebrew_command(*args)
      env_command(HOMEBREW_ENV, "brew", *args)
    end
  end
end
