#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'step'))

require 'config_loader'
require 'step'
Dir.glob(File.join(File.dirname(__FILE__), 'step', '*.rb')).each { |file| require File.basename(file, '.rb') }

class MacDevSetup
  attr_reader :dotfiles_repo, :dotfiles_dir, :home

  def initialize
    @debug = ENV['DEBUG'] == 'true'
    @dotfiles_repo = 'https://github.com/nateberkopec/dotfiles.git'
    @dotfiles_dir = File.expand_path('~/.dotfiles')
    @home = ENV['HOME']

    setup_signal_handlers
  end

  def run
    debug 'Starting macOS development environment setup...'

    step_params = {
      debug: @debug,
      dotfiles_repo: @dotfiles_repo,
      dotfiles_dir: @dotfiles_dir,
      home: @home
    }

    Step.all_steps.each do |step_class|
      step = step_class.new(**step_params)
      next unless step.should_run?
      step.run
    end

    check_completion(step_params)
  rescue => e
    puts "Error: #{e.message}"
    exit 1
  end

  private

  def check_completion(step_params)
    puts "\nChecking step completion status:"
    puts "=" * 40

    failed_steps = []

    Step.all_steps.each do |step_class|
      step = step_class.new(**step_params)
      step_name = step_class.name.gsub(/Step$/, '').gsub(/([A-Z])/, ' \1').strip

      completion_status = step.complete?
      status_symbol = case completion_status
                     when true then "✓"
                     when false then "✗"
                     when nil then "-"
                     end

      status_text = case completion_status
                   when true then "Complete"
                   when false then "Failed/Incomplete"
                   when nil then "Skipped"
                   end

      puts "#{status_symbol} #{step_name}: #{status_text}"

      failed_steps << step_name if completion_status == false
    end

    puts "=" * 40

    if failed_steps.any?
      puts "Installation failed! The following steps were incomplete:"
      failed_steps.each { |step| puts "  - #{step}" }
      exit 1
    end
  end

  def debug(message)
    puts message if @debug
  end

  def command_exists?(command)
    system("command -v #{command} >/dev/null 2>&1")
  end

  def setup_signal_handlers
    trap('EXIT') do
      debug 'Clearing SSH keys from agent...'
      system('ssh-add -D 2>/dev/null') if command_exists?('ssh-add')
    end
  end

end


if __FILE__ == $0
  MacDevSetup.new.run
end
