#!/usr/bin/env ruby

require "json"

home = ENV.fetch("HOME")
config_path = File.join(ENV.fetch("PASEO_HOME", File.join(home, ".paseo")), "config.json")
exit unless File.file?(config_path)

settings = JSON.parse(File.read(File.join(home, ".pi/agent/settings.json")))
default = "#{settings.fetch("defaultProvider")}/#{settings.fetch("defaultModel")}"
enabled = settings.fetch("enabledModels").map { |model| model.sub(/:[a-z]+\z/, "") }.uniq

config = JSON.parse(File.read(config_path))
providers = config.fetch("agents").fetch("providers")
metadata = config.dig("agents", "metadataGeneration", "providers").to_a.filter_map { |entry| entry["model"] if entry["provider"] == "pi-claude" }

labels = providers.values.flat_map { |provider| provider.fetch("models", []) }.to_h { |model| [model.fetch("id"), model["label"]] }
shortlist = lambda do |ids|
  ids.uniq.map { |id| {"id" => id, "label" => labels[id] || id.split("/").last, "isDefault" => id == default} }
end
providers.fetch("pi")["models"] = shortlist.call(enabled)
providers.fetch("pi-claude")["models"] = shortlist.call(enabled.grep(%r{\Ameridian/}) + metadata)

contents = JSON.pretty_generate(config) + "\n"
previous = File.read(config_path)
exit if previous == contents
File.write(config_path, contents)
status = IO.popen(["mise", "exec", "--", "paseo", "daemon", "status", "--json"], err: File::NULL, &:read)
unless $?.success?
  File.write(config_path, previous)
  abort("Paseo rejected the generated model shortlist; kept #{config_path} unchanged")
end
if JSON.parse(status)["connectedDaemon"] == "reachable"
  system("mise", "exec", "--", "paseo", "daemon", "reload", out: File::NULL, err: File::NULL) || abort("Paseo did not reload #{config_path}")
end
