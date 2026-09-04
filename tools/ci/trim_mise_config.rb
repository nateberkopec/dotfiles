#!/usr/bin/env ruby
require "json"

CONFIG_PATH = File.expand_path("../../files/home/.config/mise/config.toml", __dir__)

def csv(name)
  ENV.fetch(name, "").split(",").map(&:strip).reject(&:empty?)
end

def toml_string(value)
  JSON.generate(value)
end

def replace_table(content, header, entries)
  active = false
  content.lines.each_with_object([]) do |line, output|
    if line.lstrip.start_with?("[")
      active = line.strip == header
      if active
        output.concat(["#{header}\n", *entries.map { |entry| "#{entry}\n" }, "\n"]) if entries
      else
        output << line
      end
    elsif !active || line.lstrip.start_with?("#")
      output << line
    end
  end.join
end

def tool_name(line)
  match = line.match(/\A(?:"([^"]+)"|([^=\s]+))\s*=/)
  match && (match[1] || match[2])
end

def tool_entries(content)
  names = csv("MISE_CI_TOOLS")
  entries = content[/^\[tools\]\n(.*?)(?=^\[|\z)/m].lines.filter { |line| names.include?(tool_name(line)) }
  unknown = names - entries.map { |line| tool_name(line) }
  abort "Unknown MISE_CI_TOOLS: #{unknown}" unless unknown.empty?
  entries.map(&:chomp)
end

def package_entries
  csv("BREW_CI_PACKAGES").map { |name| %(#{toml_string("brew:#{name}")} = "latest") } +
    csv("DEBIAN_CI_PACKAGES").map { |name| %(#{toml_string("apt:#{name}")} = "latest") }
end

path = ARGV.fetch(0, CONFIG_PATH)
content = File.read(path)
content = replace_table(content, "[tools]", tool_entries(content)) if ENV.key?("MISE_CI_TOOLS")
if ENV.key?("BREW_CI_PACKAGES") || ENV.key?("DEBIAN_CI_PACKAGES")
  content = replace_table(content, "[bootstrap.packages]", package_entries)
end
%w[yknotify woodblock-wallpaper omniwm time-machine-backup].each do |agent|
  content = replace_table(content, "[bootstrap.macos.launchd.agents.#{agent}]", nil)
end
File.write(path, content)
