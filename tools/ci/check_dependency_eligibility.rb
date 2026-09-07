#!/usr/bin/env ruby
require_relative "dependency_factory"
require "yaml"

context = JSON.parse(File.read(ARGV.fetch(0)))
data = JSON.parse(File.read(ARGV.fetch(1)))
base = context["head"] || context.fetch("base")
changes = DependencyFactory::ChangedPins.new(base: context.fetch("base"), root: Dir.pwd).changes
policy = YAML.safe_load(DependencyFactory::Sources.capture({}, "git", "show", "#{base}:#{DependencyFactory::CONFIG_PATH}"))
snoozes = policy.fetch("snoozes", {}) || {}
current = YAML.safe_load_file(DependencyFactory::CONFIG_PATH).fetch("snoozes", {}) || {}
abort "Autonomous runs must preserve existing snoozes" unless context["owner_request"] || snoozes.all? { |name, value| current[name] == value }
cutoff = Time.iso8601(data.fetch("generated_at")) - policy.fetch("minimum_release_age_days") * 86_400
changes.each do |name, (old, version)|
  abort "Removed pin #{name}" unless version
  pin = data.fetch("candidates").find { |candidate| candidate["name"] == name }
  abort "Uninventoried dependency #{name}" unless pin || old.nil?
  releases = pin ? pin.fetch("releases") : DependencyFactory::Sources.new.gem(name)
  release = releases.find { |entry| entry["version"] == version }
  abort "Ineligible release #{name} #{version}" unless release && release["created_at"] && Time.iso8601(release["created_at"]) <= cutoff && DependencyFactory::Versions.stable?(version)
  abort "Downgrade #{name}" if old && !DependencyFactory::Versions.newer?(version, old)
  wake = current.dig(name, "wake_at")
  advisory = release["text"].to_s.match?(/\b(?:GHSA-[23456789cfghjmpqrvwx]{4}-[23456789cfghjmpqrvwx]{4}-[23456789cfghjmpqrvwx]{4}|CVE-\d{4}-\d{4,})\b/i)
  abort "Snoozed #{name} until #{wake}" if wake && DependencyFactory::Versions.newer?(wake, version) && !advisory
end
