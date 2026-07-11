require "digest"
require "fileutils"

class Dotfiles
  class Step
    @@steps = []

    extend Dotfiles::PlatformRestrictable
    include Dotfiles::CommandHelpers

    private :command, :env_command, :shell_script, :command_succeeds?, :command_exists?

    def self.inherited(subclass)
      @@steps << subclass
    end

    def self.depends_on
      []
    end

    def self.display_name
      name.gsub(/^Dotfiles::Step::/, "").gsub(/Step$/, "").gsub(/([A-Z]+)([A-Z][a-z])/, '\1 \2').gsub(/([a-z\d])([A-Z])/, '\1 \2')
    end

    def self.description
      return const_get(:DESCRIPTION, false) if const_defined?(:DESCRIPTION, false)

      "No description provided."
    end

    def self.all_steps
      topological_sort(@@steps)
    end

    def self.print_steps(io = $stdout)
      rows = all_steps.map { |step| [step.name, step.description] }
      name_width = rows.map { |row| row.first.length }.max || 0

      io.puts "Steps"
      io.puts "====="
      io.puts
      rows.each { |name, description| io.puts "#{name.ljust(name_width)}  #{description}" }
    end

    def self.topological_sort(steps)
      context = {visited: {}, temp_visited: {}, result: [], all_steps: steps}
      steps.each { |step| visit(step, context) unless context[:visited].key?(step) }
      context[:result]
    end

    def self.visit(step, context)
      validate_visit(step, context)
      visit_dependencies(step, context)
      finalize_visit(step, context)
    end

    def self.validate_visit(step, context)
      raise "Circular dependency detected involving #{step}" if context[:temp_visited].key?(step)
    end

    def self.visit_dependencies(step, context)
      return if context[:visited].key?(step)
      context[:temp_visited][step] = true
      step.depends_on.each { |dep| visit_single_dependency(dep, context) }
    end

    def self.visit_single_dependency(dependency, context)
      raise "Dependency #{dependency} not found in step list" unless context[:all_steps].include?(dependency)
      visit(dependency, context)
    end

    def self.finalize_visit(step, context)
      context[:temp_visited].delete(step)
      return if context[:visited].key?(step)
      context[:visited][step] = true
      context[:result] << step
    end

    def initialize(debug:, dotfiles_repo:, dotfiles_dir:, home:, system: SystemAdapter.new, config: nil)
      @debug, @dotfiles_repo, @dotfiles_dir, @home, @system = debug, dotfiles_repo, dotfiles_dir, home, system
      @config = config || Config.new(dotfiles_dir, system: system)
      reset_state
    end

    def reset_state
      @ran, @warnings, @notices, @errors = false, [], [], []
    end

    attr_reader :warnings, :notices, :config, :errors

    def ran?
      @ran
    end

    def add_warning(title:, message:)
      @warnings << {title: title, message: message}
    end

    def add_notice(title:, message:)
      @notices << {title: title, message: message}
    end

    def add_error(message)
      @errors << message
    end

    def should_run?
      allowed_on_platform? && !complete?
    end

    def run
      raise NotImplementedError, "Subclasses must implement #run"
    end

    def complete?
      @errors.clear
      false
    end

    # Validate the step and return its error messages. This is the explicit
    # entry point for collecting errors for display; it clears @errors, runs
    # the complete? check (which populates @errors), and returns a duplicate
    # of the collected errors. complete? remains a boolean predicate that
    # callers can use directly, but the Runner routes validation through here
    # so the display path does not depend on the predicate's side effect.
    def collect_errors
      @errors.clear
      complete?
      errors.dup
    end

    def allowed_on_platform?
      return false if self.class.macos_only? && !@system.macos?
      return false if self.class.debian_only? && !@system.debian?
      true
    end

    private

    def debug(message)
      Dotfiles.debug(message)
    end

    def execute(command, quiet: true)
      run_command(command, quiet: quiet)
    end

    def run_command(cmd, quiet:)
      debug "Executing: #{Dotfiles::Command.display(cmd)}"
      @system.execute(cmd, quiet: quiet)
    end

    def sudo_command(*parts)
      root? ? command(*parts) : command("sudo", *parts)
    end

    def format_command_error(command, status, output)
      cleaned = output.to_s.strip.gsub(/\s+/, " ")
      display_command = Dotfiles::Command.display(command)
      return "#{display_command} failed (status #{status})" if cleaned.empty?

      "#{display_command} failed (status #{status}): #{cleaned}"
    end

    def brew_quiet(*args)
      @system.execute(env_command({"HOMEBREW_NO_AUTO_UPDATE" => "1", "HOMEBREW_NO_ENV_HINTS" => "1"}, "brew", *args))
    end

    def user_has_admin_rights?
      groups, = @system.execute(command("groups"))
      groups.include?("admin")
    end

    def copy_if_exists(src, dest)
      return unless src && dest && @system.file_exist?(src)
      @system.mkdir_p(File.dirname(dest))
      @system.cp(src, dest)
    end

    def defaults_read_equals?(command, expected_value)
      output, status = execute(command, quiet: true)
      return false unless status == 0
      output == normalize_defaults_value(expected_value)
    end

    def expand_path_with_home(path)
      expanded = path.sub(/^~/, @home)
      File.expand_path(expanded)
    end

    def collapse_path_to_home(path)
      return path unless path.is_a?(String)
      return path unless @home && path.start_with?(@home)
      path.sub(@home, "~")
    end

    def normalize_defaults_value(value)
      str = value.is_a?(String) ? value : (value&.to_s || "")
      str.start_with?("~/") ? expand_path_with_home(str) : str
    end

    def file_hash(path)
      return nil unless path && @system.file_exist?(path)
      content = @system.read_file(path)
      Digest::MD5.hexdigest(content)
    end

    def root?
      output, status = @system.execute(command("id", "-u"))
      status == 0 && output.strip == "0"
    end

    def find_fish_path
      return @fish_path if @fish_path_resolved

      path = resolve_fish_path
      @fish_path = path
      @fish_path_resolved = !path.to_s.empty?
      path
    end

    def resolve_fish_path
      mise_fish = @system.glob(File.join(@home, ".local", "share", "mise", "installs", "aqua-fish-shell-fish-shell", "*", "{fish,fish.pkg/Payload/usr/local/bin/fish}")).max
      candidates = [
        mise_fish,
        File.join(@home, ".homebrew", "bin", "fish"),
        "/opt/homebrew/bin/fish",
        "/usr/local/bin/fish",
        "/usr/bin/fish",
        "/home/linuxbrew/.linuxbrew/bin/fish"
      ]
      candidate = candidates.compact.find { |path| @system.file_exist?(path) }
      return candidate if candidate

      output, status = @system.execute(shell_script('command -v -- "$1" 2>/dev/null', "fish"))
      (status == 0) ? output.strip : ""
    end

    def temp_path(label)
      require "securerandom"
      File.join("/tmp", "dotfiles-#{label}-#{SecureRandom.hex(6)}")
    end
  end
end
