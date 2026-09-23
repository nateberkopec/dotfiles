#!/usr/bin/env ruby
require_relative "dependency_factory"

base = ARGV.fetch(0)
abort "Expected a commit SHA" unless base.match?(/\A[0-9a-f]{40}\z/)
config_path = "files/home/.config/mise/config.toml"
version_path = "config/mise.version"
before_config = DependencyFactory::Sources.capture({}, "git", "show", "#{base}:#{config_path}")
before_tools = TomlRB.parse(before_config).fetch("tools", {})
after_tools = TomlRB.parse(File.read(config_path)).fetch("tools", {})

if DependencyFactory::Sources.capture({}, "git", "show", "#{base}:#{version_path}") != File.read(version_path)
  puts "--all"
elsif (before_tools.keys - after_tools.keys).any?
  puts "--all"
else
  targets = after_tools.filter_map { |name, spec| name if before_tools[name] != spec }
  if targets.any?
    puts targets
  elsif !system("git", "diff", "--quiet", base, "--", "files/home/.config/mise/mise.lock")
    abort "mise.lock changed without a corresponding mise input change"
  end
end
