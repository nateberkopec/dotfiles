#!/usr/bin/env ruby
require_relative "dependency_factory"
require "fileutils"
require "json"
require "yaml"

output = ARGV.fetch(0, "/tmp/gh-aw/agent/dependency-candidates.json")
root = DependencyFactory::ROOT
days = YAML.safe_load_file(File.join(root, DependencyFactory::CONFIG_PATH)).fetch("minimum_release_age_days")
pins = DependencyFactory::Manifests::PATHS.flat_map { |path| DependencyFactory::Manifests.pins(path, File.read(File.join(root, path))) }
result = DependencyFactory::Candidates.new(sources: DependencyFactory::Sources.new, days: days).build(pins)
FileUtils.mkdir_p(File.dirname(output))
File.write(output, JSON.pretty_generate(result))
result["candidates"].each do |candidate|
  gated = (candidate["latest"] == candidate["eligible"]) ? "" : " (#{candidate["latest"]} is inside the release gate)"
  puts "#{candidate["name"]}: #{candidate["current"]} -> #{candidate["eligible"]}#{gated}"
end
puts "#{result["candidates"].size} candidate(s) and #{result["observation_only"].size} observation-only pin(s) written to #{output}"
