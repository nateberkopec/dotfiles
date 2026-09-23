#!/usr/bin/env ruby
require_relative "dependency_factory"

base = ARGV.fetch(0)
abort "Expected a commit SHA" unless base.match?(/\A[0-9a-f]{40}\z/)
path = "files/home/.config/mise/config.toml"
before = DependencyFactory::Manifests.mise_tools(path, DependencyFactory::Sources.capture({}, "git", "show", "#{base}:#{path}"))
after = DependencyFactory::Manifests.mise_tools(path, File.read(path))
old_pins = before.to_h { |pin| [pin.name, pin.current] }
new_pins = after.to_h { |pin| [pin.name, pin.current] }

targets = new_pins.filter_map { |name, version| name if old_pins[name] != version }
if (old_pins.keys - new_pins.keys).any?
  puts "--all"
elsif targets.any?
  puts targets
elsif !system("git", "diff", "--quiet", base, "--", "files/home/.config/mise/mise.lock")
  abort "mise.lock changed without a corresponding global mise pin"
end
