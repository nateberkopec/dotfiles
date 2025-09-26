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

    puts ""
    Step.all_steps.each do |step_class|
      step = step_class.new(**step_params)
      if step.should_run?
        printf "X"
        step.run
      else
        printf "."
      end
    end
    puts ""

    check_completion(step_params)
  rescue => e
    puts "Error: #{e.message}"
    exit 1
  end

  private

  def check_completion(step_params)
    failed_steps = []
    table_data = []

    Step.all_steps.each do |step_class|
      step = step_class.new(**step_params)
      step_name = step_class.name.gsub(/Step$/, '').gsub(/([A-Z])/, ' \1').strip

      completion_status = !!step.complete?
      status_symbol = case completion_status
                     when true then "✓"
                     when false then "✗"
                     end

      ran_status = step.should_run? ? "Yes" : "No"

      table_data << "#{step_name},#{status_symbol},#{ran_status}"
      failed_steps << step_name if completion_status == false
    end

    csv_data = "Step,Status,Ran?\n" + table_data.join("\n")
    IO.popen(["gum", "table", "--border", "rounded", "--widths", "25,8,8", "--print"], "w") do |io|
      io.write(csv_data)
    end

    if failed_steps.any?
      system(
        "gum", "style",
        "--foreground", "#ff5555",
        "--border", "thick",
        "--align", "center",
        "--width", "60",
        "--margin", "1 0",
        "--padding", "1 2",
        "❌ Installation Failed!",
        "",
        "Incomplete steps:",
        *failed_steps.map { |step| "• #{step}" }
      )
      exit 1
    else
      system(
        "gum", "style",
        "--foreground", "#50fa7b",
        "--border", "rounded",
        "--align", "center",
        "--width", "50",
        "--margin", "1 0",
        "--padding", "1 2",
        "🎉 All Steps Complete!",
        "Setup successful"
      )
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
