#!/usr/bin/env ruby
require_relative "dependency_factory"
require "fileutils"
require "json"
require "yaml"

output = ARGV.fetch(0, "/tmp/gh-aw/agent/dependency-candidates.json")
root = DependencyFactory::ROOT
days = YAML.safe_load_file(File.join(root, DependencyFactory::CONFIG_PATH)).fetch("minimum_release_age_days")
base = ARGV[1]
abort "Expected a commit SHA" if base && !base.match?(/\A[0-9a-f]{40}\z/)
pins = DependencyFactory::Manifests::PATHS.flat_map do |path|
  content = base ? DependencyFactory::Sources.capture({}, "git", "-C", root, "show", "#{base}:#{path}") : File.read(File.join(root, path))
  DependencyFactory::Manifests.pins(path, content)
end
now = ARGV[2].to_s.empty? ? Time.now : Time.iso8601(ARGV[2])
result = DependencyFactory::Candidates.new(sources: DependencyFactory::Sources.new, days: days, now: now).build(pins)
FileUtils.mkdir_p(File.dirname(output))
File.write(output, JSON.pretty_generate(result))
result["candidates"].each do |candidate|
  gated = (candidate["latest"] == candidate["eligible"]) ? "" : " (#{candidate["latest"]} is inside the release gate)"
  puts "#{candidate["name"]}: #{candidate["current"]} -> #{candidate["eligible"]}#{gated}"
end
puts "#{result["candidates"].size} candidate(s) and #{result["observation_only"].size} observation-only pin(s) written to #{output}"
