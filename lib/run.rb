#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "step"))

require "config_loader"
require "step"
Dir.glob(File.join(File.dirname(__FILE__), "step", "*.rb")).each { |file| require File.basename(file, ".rb") }

class MacDevSetup
  attr_reader :dotfiles_repo, :dotfiles_dir, :home

  def initialize
    @debug = ENV["DEBUG"] == "true"
    @dotfiles_repo = "https://github.com/nateberkopec/dotfiles.git"
    @dotfiles_dir = File.expand_path("~/.dotfiles")
    @home = ENV["HOME"]

    setup_signal_handlers
  end

  def run
    debug "Starting macOS development environment setup..."

    step_params = {
      debug: @debug,
      dotfiles_repo: @dotfiles_repo,
      dotfiles_dir: @dotfiles_dir,
      home: @home
    }

    step_instances = []

    puts ""
    Step.all_steps.each do |step_class|
      step = step_class.new(**step_params)
      step_instances << step
      if step.should_run?
        printf "X"
        step.instance_variable_set(:@ran, true)
        step.run
      else
        printf "."
      end
    end
    puts ""

    check_completion(step_params, step_instances)
  rescue => e
    puts "Error: #{e.message}"
    exit 1
  end

  private

  def check_completion(step_params, step_instances)
    failed_steps = []
    table_data = []
    skipped_homebrew_packages = []
    skipped_homebrew_casks = []
    needs_1password_setup = false

    Step.all_steps.each_with_index do |step_class, i|
      step = step_instances[i]
      step_name = step_class.name.gsub(/Step$/, "").gsub(/([A-Z])/, ' \1').strip

      completion_status = !!step.complete?
      status_symbol = case completion_status
      when true then "✓"
      when false then "✗"
      end

      ran_status = step.ran? ? "Yes" : "No"

      table_data << "#{step_name},#{status_symbol},#{ran_status}"
      failed_steps << step_name if completion_status == false

      if step.respond_to?(:skipped_packages) && step.skipped_packages.any?
        skipped_homebrew_packages.concat(step.skipped_packages)
      end
      if step.respond_to?(:skipped_casks) && step.skipped_casks.any?
        skipped_homebrew_casks.concat(step.skipped_casks)
      end
      if step.respond_to?(:needs_manual_setup) && step.needs_manual_setup
        needs_1password_setup = true
      end
    end

    csv_data = "Step,Status,Ran?\n" + table_data.join("\n")
    IO.popen(["gum", "table", "--border", "rounded", "--widths", "25,8,8", "--print"], "w") do |io|
      io.write(csv_data)
    end

    if needs_1password_setup
      system(
        "gum", "style",
        "--foreground", "#00aaff",
        "--border", "rounded",
        "--align", "left",
        "--width", "60",
        "--margin", "1 0",
        "--padding", "1 2",
        "ℹ️  1Password SSH Agent Setup Required",
        "",
        "To complete SSH setup:",
        "1. Open 1Password app",
        "2. Go to Settings → Developer",
        "3. Enable 'Use the SSH agent'"
      )
    end

    if skipped_homebrew_packages.any? || skipped_homebrew_casks.any?
      warning_lines = [
        "⚠️  Homebrew Installation Skipped",
        "",
        "No admin rights detected."
      ]

      if skipped_homebrew_packages.any?
        warning_lines << ""
        warning_lines << "Skipped formulae:"
        warning_lines.concat(skipped_homebrew_packages.map { |pkg| "• #{pkg}" })
      end

      if skipped_homebrew_casks.any?
        warning_lines << ""
        warning_lines << "Skipped casks:"
        warning_lines.concat(skipped_homebrew_casks.map { |cask| "• #{cask}" })
      end

      system(
        "gum", "style",
        "--foreground", "#ffaa00",
        "--border", "rounded",
        "--align", "left",
        "--width", "60",
        "--margin", "1 0",
        "--padding", "1 2",
        *warning_lines
      )
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
    trap("EXIT") do
      system("ssh-add -D 2>/dev/null") if command_exists?("ssh-add")
    end
  end
end
