#!/usr/bin/env ruby

require "fileutils"
require "open3"

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "step"))

require "config_loader"
require "step"
Dir.glob(File.join(File.dirname(__FILE__), "step", "*.rb")).each { |file| require File.basename(file, ".rb") }

class DotfilesUpdater
  def initialize
    @debug = ENV["DEBUG"] == "true"
    @dotfiles_repo = "https://github.com/nateberkopec/dotfiles.git"
    @dotfiles_dir = File.expand_path("~/.dotfiles")
    @home = ENV["HOME"]

    unless Dir.exist?(@dotfiles_dir)
      puts "Error: Dotfiles directory not found at #{@dotfiles_dir}"
      puts "Please run the initial setup script first."
      exit 1
    end
  end

  def run
    puts "Updating dotfiles repository via step updates..."

    step_params = {
      debug: @debug,
      dotfiles_repo: @dotfiles_repo,
      dotfiles_dir: @dotfiles_dir,
      home: @home
    }

    Step.all_steps.each do |step_class|
      step = step_class.new(**step_params)
      # Each step may implement update to sync back into repo
      step.update
    end

    commit_and_push_changes
  end

  private

  def commit_and_push_changes
    Dir.chdir(@dotfiles_dir)
    stdout, _stderr, _ = Open3.capture3("git status --porcelain")
    return puts "No changes to commit." if stdout.empty?

    system("git add -A")
    system("git diff --cached --stat")
    system("gc-ai") || system("git commit -m 'Update dotfiles from system'")

    puts "Dotfiles updated successfully!"
  end

  def command_exists?(cmd)
    system("command -v #{cmd} >/dev/null 2>&1")
  end
end
