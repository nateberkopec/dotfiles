#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
source=$(ruby -rjson -e '
  settings = JSON.parse(File.read(ARGV.fetch(0)))
  packages = settings.fetch("packages").map { |p| p.is_a?(Hash) ? p.fetch("source") : p }
  puts packages.find { |p| p.start_with?("git:github.com/nateberkopec/agent-stuff@") } || abort("agent-stuff source missing")
' "$root/files/home/.pi/agent/settings.json")
mkdir -p "$root/tmp/agent-stuff"
ruby -rjson -e 'puts JSON.generate("npmCommand" => ["bash", "-c", "exec bash \"$1\" \"${@:2}\"", "npm", ARGV.fetch(0)])' \
  "$root/files/home/.pi/agent/pi-npm.sh" > "$root/tmp/agent-stuff/settings.json"
PI_CODING_AGENT_DIR="$root/tmp/agent-stuff" pi install "$source"
