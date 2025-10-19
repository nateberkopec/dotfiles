#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path("dotfiles", __dir__))

require "config"
require "system_adapter"
require "step"
Dir.glob(File.join(__dir__, "dotfiles", "steps", "*.rb")).sort.each { |file| require file }
require "runner"
require "updater"

class Dotfiles
  def self.debug(message)
    puts message if ENV["DEBUG"] == "true"
  end

  def self.command_exists?(command)
    system("command -v #{command} >/dev/null 2>&1")
  end
end
