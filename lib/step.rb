require "fileutils"
require "json"
require "open3"
require "shellwords"
require "yaml"

class Step
  @@steps = []

  def self.inherited(subclass)
    @@steps << subclass
  end

  def self.depends_on
    []
  end

  def self.display_name
    name.gsub(/Step$/, "").gsub(/([A-Z]+)([A-Z][a-z])/, '\1 \2').gsub(/([a-z\d])([A-Z])/, '\1 \2')
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

  def initialize(debug:, dotfiles_repo:, dotfiles_dir:, home:)
    @debug = debug
    @dotfiles_repo = dotfiles_repo
    @dotfiles_dir = dotfiles_dir
    @home = home
    @config = ConfigLoader.new(dotfiles_dir)
    @ran = false
  end

  def ran?
    @ran
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
    puts message if @debug
  end

  def execute(command, quiet: true, sudo: false, capture_output: false)
    if sudo && ci_or_noninteractive?
      debug "Skipping sudo command in CI/non-interactive environment: #{command}"
      return ""
    end

    if sudo
      step_name = self.class.name.gsub(/Step$/, "").gsub(/([A-Z])/, ' \1').strip
      system(
        "gum", "style",
        "--foreground", "#ff6b6b",
        "--border", "double",
        "--align", "center",
        "--width", "50",
        "--margin", "1 0",
        "--padding", "1 2",
        "🔒 Admin Privileges Required",
        step_name,
        "",
        "Command: #{command}",
        "",
        "This is required to complete setup"
      )
      cmd = "sudo #{command}"
    else
      cmd = command
    end

    debug "Executing: #{cmd}"

    if quiet || capture_output
      stdout, stderr, status = Open3.capture3(cmd)
      raise "Command failed: #{cmd}\n#{stderr}" unless status.success?
      stdout
    else
      system(cmd) || raise("Command failed: #{cmd}")
    end
  end

  def command_exists?(command)
    system("command -v #{command} >/dev/null 2>&1")
  end

  def brew_quiet(command)
    execute("brew #{command}", quiet: true)
  end

  def ci_or_noninteractive?
    ENV["CI"] || ENV["NONINTERACTIVE"]
  end

  def user_has_admin_rights?
    groups = `groups`.strip
    groups.include?("admin")
  end
end
