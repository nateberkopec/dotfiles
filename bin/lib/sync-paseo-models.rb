#!/usr/bin/env ruby

require "json"

home = ENV.fetch("HOME")
config_path = File.join(ENV.fetch("PASEO_HOME", File.join(home, ".paseo")), "config.json")
exit unless File.file?(config_path)
exit unless system("mise", "which", "paseo", out: File::NULL, err: File::NULL)

settings = JSON.parse(File.read(File.join(home, ".pi/agent/settings.json")))
enabled = settings.fetch("enabledModels").map { |entry| entry.match(/\A(?<model>.+?)(?::(?<thinking>[a-z]+))?\z/) }

config = JSON.parse(File.read(config_path))
providers = config.fetch("agents").fetch("providers")
providers.fetch("pi").delete("models")

config.fetch("daemon")["agentProfiles"] = enabled.map do |entry|
  {
    "id" => "pi:#{entry[:model]}",
    "name" => entry[:model].split("/").last,
    "provider" => "pi",
    "model" => entry[:model],
    "thinkingOptionId" => entry[:thinking]
  }.compact
end

contents = JSON.pretty_generate(config) + "\n"
previous = File.read(config_path)
exit if previous == contents
File.write(config_path, contents)
status = IO.popen(["mise", "exec", "--", "paseo", "daemon", "status", "--json"], err: File::NULL, &:read)
unless $?.success?
  File.write(config_path, previous)
  abort("Paseo rejected the generated agent profiles; kept #{config_path} unchanged")
end
if JSON.parse(status)["connectedDaemon"] == "reachable"
  system("mise", "exec", "--", "paseo", "daemon", "reload", out: File::NULL, err: File::NULL) || abort("Paseo did not reload #{config_path}")
end
