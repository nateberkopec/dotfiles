require 'fileutils'
require 'json'
require 'open3'
require 'shellwords'

class Step
  @@steps = []

  def self.inherited(subclass)
    @@steps << subclass
  end

  def self.all_steps
    @@steps
  end

  def initialize(debug:, dotfiles_repo:, dotfiles_dir:, home:)
    @debug = debug
    @dotfiles_repo = dotfiles_repo
    @dotfiles_dir = dotfiles_dir
    @home = home
  end

  def should_run?
    true
  end

  def run
    raise NotImplementedError, 'Subclasses must implement #run'
  end

  def complete?
    raise NotImplementedError, 'Subclasses must implement #complete?'
  end

  private

  def debug(message)
    puts message if @debug
  end

  def execute(command, quiet: !@debug, sudo: false, capture_output: false)
    if sudo && ci_or_noninteractive?
      debug "Skipping sudo command in CI/non-interactive environment: #{command}"
      return ""
    end

    cmd = sudo ? "sudo #{command}" : command
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
    execute("brew #{command}", quiet: !@debug)
  end

  def ci_or_noninteractive?
    ENV['CI'] || ENV['NONINTERACTIVE']
  end
end