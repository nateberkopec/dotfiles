#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path("dotfiles", __dir__))

require "config"
require "system_adapter"
require "step"
require "step/defaultable"
require "step/sudoable"
Dir.glob(File.join(__dir__, "dotfiles", "steps", "*.rb")).sort.each { |file| require file }
require "runner"
require "updater"

class Dotfiles
  @log_file = nil

  def self.log_file=(path)
    @log_file = path
  end

  def self.log_file
    @log_file
  end

  def self.debug(message)
    timestamp = Time.now.strftime("%H:%M:%S.%3N")
    formatted = "[#{timestamp}] #{message}"

    # Always write to log file if set
    if @log_file
      File.open(@log_file, "a") { |f| f.puts(formatted) }
    end

    # Also output to STDOUT if DEBUG=true
    puts formatted if ENV["DEBUG"] == "true"
  end

  def self.debug_benchmark(label, &block)
    start = Time.now
    result = block.call
    elapsed = ((Time.now - start) * 1000).round(2)
    debug "#{label} took #{elapsed}ms"
    result
  end

  def self.command_exists?(command)
    system("command -v #{command} >/dev/null 2>&1")
  end

  def self.determine_dotfiles_dir
    # In CI, the dotfiles are in the current working directory
    # In normal usage, they're in ~/.dotfiles
    if ENV["CI"]
      Dir.pwd
    else
      File.expand_path("~/.dotfiles")
    end
  end
end
