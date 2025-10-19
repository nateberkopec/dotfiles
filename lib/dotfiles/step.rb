require "digest"
require "fileutils"
require "open3"

class Dotfiles
  class Step
    @@steps = []

    def self.inherited(subclass)
      @@steps << subclass
    end

    def self.depends_on
      []
    end

    def self.display_name
      name.gsub(/^Dotfiles::Step::/, "").gsub(/Step$/, "").gsub(/([A-Z]+)([A-Z][a-z])/, '\1 \2').gsub(/([a-z\d])([A-Z])/, '\1 \2')
    end

    def self.all_steps
      topological_sort(@@steps)
    end

    def self.topological_sort(steps)
      visited = Set.new
      temp_visited = Set.new
      result = []

      steps.each do |step|
        visit(step, visited, temp_visited, result, steps) unless visited.include?(step)
      end

      result
    end

    def self.visit(step, visited, temp_visited, result, all_steps)
      raise "Circular dependency detected involving #{step}" if temp_visited.include?(step)
      return if visited.include?(step)

      temp_visited.add(step)

      step.depends_on.each do |dependency|
        raise "Dependency #{dependency} not found in step list" unless all_steps.include?(dependency)
        visit(dependency, visited, temp_visited, result, all_steps)
      end

      temp_visited.delete(step)
      visited.add(step)
      result << step
    end

    def initialize(config:, system: SystemAdapter.new)
      @config = config
      @system = system
      @ran = false
      @warnings = []
      @notices = []
    end

    attr_reader :warnings, :notices

    def ran?
      @ran
    end

    def add_warning(title:, message:)
      @warnings << {title: title, message: message}
    end

    def add_notice(title:, message:)
      @notices << {title: title, message: message}
    end

    def should_run?
      !complete?
    end

    def run
      raise NotImplementedError, "Subclasses must implement #run"
    end

    def complete?
      raise NotImplementedError, "Subclasses must implement #complete?"
    end

    # Optional: steps can implement update logic to sync
    # configuration from the system back into the dotfiles repo.
    # Default is a no-op.
    def update
      # no-op by default
    end

    private

    def debug(message)
      puts message if @config.debug
    end

    def execute(command, quiet: true, sudo: false)
      if sudo && ci_or_noninteractive?
        debug "Skipping sudo command in CI/non-interactive environment: #{command}"
        return ["", 0]
      end

      if sudo
        step_name = self.class.name.gsub(/Step$/, "").gsub(/([A-Z])/, ' \1').strip
        @system.execute(
          "gum style --foreground '#ff6b6b' --border double --align center --width 50 --margin '1 0' --padding '1 2' '🔒 Admin Privileges Required' '#{step_name}' '' 'Command: #{command}' '' 'This is required to complete setup'",
          quiet: false
        )
        cmd = "sudo #{command}"
      else
        cmd = command
      end

      debug "Executing: #{cmd}"

      @system.execute(cmd, quiet: quiet)
    end

    def command_exists?(command)
      _, status = @system.execute("command -v #{command} >/dev/null 2>&1")
      status == 0
    end

    def brew_quiet(command)
      execute("brew #{command}", quiet: true)
    end

    def ci_or_noninteractive?
      ENV["CI"] || ENV["NONINTERACTIVE"]
    end

    def user_has_admin_rights?
      groups, = @system.execute("groups")
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
      output == expected_value
    end

    def home_path(key)
      path = @config.paths.dig("home_paths", key.to_s)
      path ? expand_path_with_home(path) : nil
    end

    def app_path(key)
      path = @config.paths.dig("application_paths", key.to_s)
      path ? expand_path_with_home(path) : nil
    end

    def expand_path_with_home(path)
      expanded = path.sub(/^~/, @home)
      File.expand_path(expanded)
    end

    def dotfiles_source(key)
      source = @config.paths.dig("dotfiles_sources", key.to_s)
      source ? File.join(@config.dotfiles_dir, source) : nil
    end

    def file_hash(path)
      return nil unless path && @system.file_exist?(path)
      content = @system.read_file(path)
      Digest::MD5.hexdigest(content)
    end

    def files_match?(file1, file2)
      return false unless file1 && file2
      return false unless @system.file_exist?(file1) && @system.file_exist?(file2)
      file_hash(file1) == file_hash(file2)
    end
  end
end
