require "digest"
require "fileutils"

class Dotfiles
  class Step
    @@steps = []

    def self.inherited(subclass)
      @@steps << subclass
    end

    def self.depends_on
      []
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

    def self.system_packages_steps
      [Dotfiles::Step::InstallBrewPackagesStep, Dotfiles::Step::InstallDebianPackagesStep]
    end

    def self.display_name
      name.gsub(/^Dotfiles::Step::/, "").gsub(/Step$/, "").gsub(/([A-Z]+)([A-Z][a-z])/, '\1 \2').gsub(/([a-z\d])([A-Z])/, '\1 \2')
    end

    def self.all_steps
      topological_sort(@@steps)
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

    def initialize(debug:, dotfiles_repo:, dotfiles_dir:, home:, system: SystemAdapter.new)
      @debug, @dotfiles_repo, @dotfiles_dir, @home, @system = debug, dotfiles_repo, dotfiles_dir, home, system
      @config = Config.new(dotfiles_dir, system: system)
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

    def allowed_on_platform?
      return false if self.class.macos_only? && !@system.macos?
      return false if self.class.debian_only? && !@system.debian?
      true
    end

    # Optional: steps can implement update logic to sync
    # configuration from the system back into the dotfiles repo.
    # Default is a no-op.
    def update
      # no-op by default
    end

    private

    def debug(message)
      Dotfiles.debug(message)
    end

    def execute(command, quiet: true)
      run_command(command, quiet: quiet)
    end

    def run_command(cmd, quiet:)
      debug "Executing: #{cmd}"
      @system.execute(cmd, quiet: quiet)
    end

    def command_succeeds?(command)
      _, status = @system.execute(command)
      status == 0
    end

    def command_exists?(command)
      command_succeeds?("command -v #{command} >/dev/null 2>&1")
    end

    def brew_quiet(command)
      @system.execute("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew #{command} 2>&1")
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

    def files_match?(file1, file2)
      return false unless file1 && file2
      return false unless @system.file_exist?(file1) && @system.file_exist?(file2)
      file_hash(file1) == file_hash(file2)
    end

    def sudo_prefix
      return "" if root?
      "sudo "
    end

    def root?
      output, status = @system.execute("id -u")
      status == 0 && output.strip == "0"
    end

    def find_fish_path
      return @fish_path if defined?(@fish_path) && !@fish_path.to_s.empty?

      output, status = @system.execute("command -v fish 2>/dev/null")
      return @fish_path = output.strip if status == 0 && !output.strip.empty?

      candidates = [
        "/opt/homebrew/bin/fish",
        "/usr/local/bin/fish",
        "/usr/bin/fish",
        "/home/linuxbrew/.linuxbrew/bin/fish"
      ]
      @fish_path = candidates.find { |path| @system.file_exist?(path) }.to_s
    end

    def temp_path(label)
      require "securerandom"
      File.join("/tmp", "dotfiles-#{label}-#{SecureRandom.hex(6)}")
    end
  end
end
