#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "optparse"

class Dotenv
  def self.read(path)
    File.readlines(path, chomp: true).each_with_index.with_object({}) do |(line, index), values|
      next if line.strip.empty? || line.lstrip.start_with?("#")

      match = line.match(/\A([A-Za-z_][A-Za-z0-9_]*)=(.*)\z/)
      abort "Unsupported dotenv syntax on line #{index + 1}" unless match
      values[match[1]] = value(match[2], index + 1)
    end
  end

  def self.value(raw, line)
    return raw if raw.empty? || raw.match?(/\A[^\s#'"`$\\]+\z/)
    return raw[1...-1] if raw.match?(/\A'[^']*'\z/)
    return raw[1...-1].gsub(/\\([\\"])/, "\\1") if raw.match?(/\A"(?:[^"\\$`]|\\[\\"])*"\z/)

    abort "Unsupported dotenv value syntax on line #{line}"
  end
end

def item_template(title, values)
  {
    title: title,
    category: "API_CREDENTIAL",
    fields: values.map do |name, value|
      {id: name, label: name, type: "CONCEALED", value: value}
    end
  }
end

def toml(vault, title, names)
  lines = ["[providers.op]", 'type = "1password"', "", "[secrets]"]
  names.each { |name| lines << %(#{name} = { provider = "op", value = "op://#{vault}/#{title}/#{name}" }) }
  lines.join("\n") + "\n"
end

options = {vault: "Private", output: "fnox.toml", dry_run: false, verify: false, delete_source: false}
OptionParser.new do |parser|
  parser.on("--env-file PATH") { |value| options[:env_file] = value }
  parser.on("--vault NAME") { |value| options[:vault] = value }
  parser.on("--item-title NAME") { |value| options[:title] = value }
  parser.on("--output PATH") { |value| options[:output] = value }
  parser.on("--dry-run") { options[:dry_run] = true }
  parser.on("--verify") { options[:verify] = true }
  parser.on("--delete-source") { options[:delete_source] = true }
end.parse!

abort "--env-file and --item-title are required" unless options[:env_file] && options[:title]
[options[:vault], options[:title]].each do |value|
  abort "Vault and item title may contain only letters, numbers, spaces, dots, underscores, and hyphens" unless value.match?(/\A[A-Za-z0-9._ -]+\z/)
end
values = Dotenv.read(options[:env_file])
abort "No dotenv assignments found" if values.empty?

if options[:dry_run]
  puts "Would migrate #{values.size} variables: #{values.keys.sort.join(", ")}"
  exit
end

stdin = JSON.generate(item_template(options[:title], values))
_stdout, stderr, status = Open3.capture3(
  "op", "item", "create", "--vault", options[:vault], "--template", "/dev/stdin", stdin_data: stdin
)
abort "1Password item creation failed (secret output suppressed)" unless status.success?
abort "1Password emitted unexpected diagnostics; aborting (content suppressed)" unless stderr.empty?

File.write(options[:output], toml(options[:vault], options[:title], values.keys), mode: "w", perm: 0o600)

if options[:verify]
  values.each_key do |name|
    system("fnox", "--config", options[:output], "get", name, out: File::NULL, err: File::NULL) || abort("Verification failed for #{name}")
  end
end

if options[:delete_source]
  warn "Type DELETE to remove #{options[:env_file]} after successful migration:"
  if $stdin.gets&.chomp == "DELETE"
    File.delete(options[:env_file])
    puts "Migration complete; source removed."
  else
    puts "Migration complete; source retained."
  end
else
  puts "Migration complete; source retained."
end
