#!/usr/bin/env ruby

require "json"
require "open3"

class DeadCodeCheck
  DEFAULT_PATHS = %w[lib tools].freeze
  WHITELIST_PATH = ".debride-whitelist"

  def run
    output = debride_output
    missing_methods = JSON.parse(output).fetch("missing")
    if missing_methods.empty?
      puts "No dead Ruby methods detected."
      return
    end

    warn "Debride found potentially dead Ruby methods:"
    missing_methods.each do |owner, methods|
      warn "\n#{owner}"
      methods.each do |name, location|
        warn "  #{name} #{location}"
      end
    end
    warn "\nRemove these methods or add intentional false positives to #{WHITELIST_PATH}."
    exit 1
  rescue JSON::ParserError => e
    abort "Could not parse debride output: #{e.message}"
  end

  private

  def debride_output
    command = ["bundle", "exec", "debride", "--json"]
    command += ["--whitelist", WHITELIST_PATH] if File.exist?(WHITELIST_PATH)
    command += DEFAULT_PATHS

    output, status = Open3.capture2e(*command)
    abort output unless status.success?

    output
  end
end

DeadCodeCheck.new.run
