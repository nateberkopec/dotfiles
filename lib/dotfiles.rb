#!/usr/bin/env ruby

require_relative "dotfiles/config"
require_relative "dotfiles/step"
Dir.glob(File.join(__dir__, "dotfiles", "steps", "*.rb")).sort.each { |file| require file }
require_relative "dotfiles/runner"
require_relative "dotfiles/updater"

class Dotfiles
  def self.debug(message)
    puts message if ENV["DEBUG"] == "true"
  end

  def self.command_exists?(command)
    system("command -v #{command} >/dev/null 2>&1")
  end
end
