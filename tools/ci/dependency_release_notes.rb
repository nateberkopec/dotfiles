#!/usr/bin/env ruby
require_relative "dependency_factory"
require "fileutils"

abort "Usage: #{$PROGRAM_NAME} CANDIDATES_JSON OUTPUT_JSON" unless ARGV.size == 2
input, output = ARGV
result = DependencyFactory::ReleaseNotes.new.build(JSON.parse(File.read(input)))
FileUtils.mkdir_p(File.dirname(output))
File.write(output, JSON.pretty_generate(result))
