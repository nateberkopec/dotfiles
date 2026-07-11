#!/usr/bin/env ruby
# Trims files/home/.config/mise/config.toml down to the small package/tool
# sets CI installs, so integration runs exercise the full `mise bootstrap`
# machinery without installing every declared package. Reads the same env
# vars the workflow always used:
#
#   MISE_CI_TOOLS      - comma-separated tool specs, e.g. "fzf@latest,gh@2.96.0"
#   BREW_CI_PACKAGES   - comma-separated brew formulae
#   DEBIAN_CI_PACKAGES - comma-separated apt packages
#
# Also drops the sections that can't run on CI runners (launchd agents).

CONFIG_PATH = File.expand_path(File.join(__dir__, "..", "..", "files", "home", ".config", "mise", "config.toml"))

def csv(name)
  ENV.fetch(name, "").split(",").map(&:strip).reject(&:empty?)
end

def tool_entries
  csv("MISE_CI_TOOLS").map do |spec|
    name, separator, version = spec.rpartition("@")
    if separator.empty?
      name = spec
      version = "latest"
    end
    %(#{name.inspect} = #{version.inspect})
  end
end

def package_entries
  csv("BREW_CI_PACKAGES").map { |pkg| %("brew:#{pkg}" = "latest") } +
    csv("DEBIAN_CI_PACKAGES").map { |pkg| %("apt:#{pkg}" = "latest") }
end

# Replaces the body of the named TOML table, or removes the table when body
# is nil. Only handles the flat table layout this repo's config uses.
def replace_table(content, header, body)
  lines = content.lines
  out = []
  index = 0
  while index < lines.length
    unless lines[index].strip == header
      out << lines[index]
      index += 1
      next
    end

    index += 1
    index += 1 while index < lines.length && !lines[index].start_with?("[")
    next if body.nil?

    out << "#{header}\n"
    out.concat(body.map { |line| "#{line}\n" })
    out << "\n"
  end
  out.join
end

content = File.read(CONFIG_PATH)
content = replace_table(content, "[tools]", tool_entries) if ENV.key?("MISE_CI_TOOLS")
if %w[BREW_CI_PACKAGES DEBIAN_CI_PACKAGES].any? { |name| ENV.key?(name) }
  content = replace_table(content, "[bootstrap.packages]", package_entries)
end
content = replace_table(content, "[bootstrap.macos.launchd.agents.yknotify]", nil)
File.write(CONFIG_PATH, content)

puts "Trimmed #{CONFIG_PATH} for CI:"
puts (tool_entries + package_entries).map { |entry| "  #{entry}" }
