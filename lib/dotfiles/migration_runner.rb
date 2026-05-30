class Dotfiles
  class MigrationRunner
    attr_reader :home

    def initialize(log_file = nil, system: SystemAdapter.new, home: nil, dotfiles_dir: nil, debug: nil)
      Dotfiles.log_file = log_file if log_file
      @system = system
      @debug = debug.nil? ? ENV["DEBUG"] == "true" : debug
      @dotfiles_dir = dotfiles_dir || Dotfiles.determine_dotfiles_dir
      @config = Config.new(@dotfiles_dir, system: system)
      @home = home || @config.home
    end

    def run
      pending = pending_migrations
      return puts("No pending migrations.") if pending.empty?

      pending.each { |migration_class| run_migration(migration_class) }
    rescue => e
      abort "Error: #{e.message}"
    end

    def current_version
      return 0 unless @system.file_exist?(version_file)

      @system.read_file(version_file).to_i
    end

    def pending_migrations
      Migration.all_migrations.select { |migration| migration.version > current_version }
    end

    private

    def run_migration(migration_class)
      migration = migration_class.new(**migration_params)
      unless migration.allowed_on_platform?
        mark_version(migration_class.version)
        return
      end

      puts "Running migration #{migration_class.version}: #{migration_class.display_name}"
      migration.up
      mark_version(migration_class.version)
    end

    def migration_params
      {
        debug: @debug,
        dotfiles_repo: @config.dotfiles_repo,
        dotfiles_dir: @dotfiles_dir,
        home: @home,
        system: @system
      }
    end

    def mark_version(version)
      @system.mkdir_p(File.dirname(version_file))
      @system.write_file(version_file, "#{version}\n")
    end

    def version_file
      File.join(@home, ".local", "state", "dotf", "migration_version")
    end
  end
end
