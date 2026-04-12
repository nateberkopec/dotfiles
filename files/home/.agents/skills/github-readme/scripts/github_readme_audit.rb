#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"

Result = Struct.new(:status, :label, :details)

SECTION_PATTERNS = {
  installation: [/^\#{1,6}\s+installation\b/i, /^\#{1,6}\s+setup\b/i],
  usage: [/^\#{1,6}\s+usage\b/i, /^\#{1,6}\s+quick\s*start\b/i, /^\#{1,6}\s+getting\s+started\b/i],
  license: [/^\#{1,6}\s+license\b/i]
}.freeze

SETUP_COMMAND_HINTS = [
  /\b(?:npm|pnpm|yarn|bundle|pip|cargo|go)\s+(?:install|add|get)\b/i,
  /\bgit\s+clone\b/i,
  /\b(?:make|rake|just)\s+\w+/i,
  /\b(?:docker|docker-compose|compose)\b/i,
  /\.\/bin\/[\w-]+\b/i
].freeze

USAGE_COMMAND_HINTS = [
  /\b(?:npm|pnpm|yarn|bundle|pip|cargo|go|ruby|python)\s+(?:run|exec|test|start|serve)\b/i,
  /\b(?:make|rake|just)\s+\w+/i,
  /\.\/bin\/[\w-]+\b/i,
  /^\$\s+.+/m
].freeze

def usage_error(message)
  warn message
  warn "Usage: github_readme_audit.rb <README.md> [--strict]"
  exit 1
end

def heading_lines(text)
  text.lines.grep(/^\#{1,6}\s+/)
end

def heading_match?(headings, patterns)
  patterns.any? do |pattern|
    headings.any? { |heading| heading.match?(pattern) }
  end
end

def first_non_heading_paragraph(text)
  body = text.lines.reject { |line| line.match?(/^\#{1,6}\s+/) }.join
  paragraphs = body.split(/\n\s*\n+/).map(&:strip).reject(&:empty?)
  paragraphs.first || ""
end

def words(text)
  text.scan(/[A-Za-z0-9']+/)
end

def fenced_code_blocks(text)
  text.scan(/```(?:[^\n]*)\n(.*?)```/m).flatten
end

def has_command_block?(code_blocks, hints)
  code_blocks.any? do |block|
    hints.any? { |pattern| block.match?(pattern) }
  end
end

def check(status, label, details)
  Result.new(status, label, details)
end

options = {strict: false}

OptionParser.new do |opts|
  opts.banner = "Usage: github_readme_audit.rb <README.md> [--strict]"
  opts.on("--strict", "Enable stricter optional checks") { options[:strict] = true }
end.parse!(ARGV)

file = ARGV.shift
usage_error("Missing README path") if file.nil?
usage_error("File not found: #{file}") unless File.exist?(file)

text = File.read(file)
usage_error("File is empty: #{file}") if text.strip.empty?

headings = heading_lines(text)
code_blocks = fenced_code_blocks(text)
first_paragraph = first_non_heading_paragraph(text)
word_count = words(text).size

results = []

h1_count = text.lines.count { |line| line.match?(/^#\s+\S+/) }
results << if h1_count == 1
  check(:pass, "Exactly one H1", "1 found")
elsif h1_count.zero?
  check(:fail, "Exactly one H1", "0 found")
else
  check(:fail, "Exactly one H1", "#{h1_count} found")
end

SECTION_PATTERNS.each do |name, patterns|
  results << if heading_match?(headings, patterns)
    check(:pass, "#{name.capitalize} section", "Found")
  else
    check(:fail, "#{name.capitalize} section", "Missing")
  end
end

lead_words = words(first_paragraph).size
results << if lead_words <= 80
  check(:pass, "Lead paragraph length", "#{lead_words} words")
elsif lead_words <= 120
  check(:warn, "Lead paragraph length", "#{lead_words} words (consider tightening)")
else
  check(:fail, "Lead paragraph length", "#{lead_words} words (too long)")
end

results << if has_command_block?(code_blocks, SETUP_COMMAND_HINTS)
  check(:pass, "Setup command example", "Found in fenced code block")
else
  check(:fail, "Setup command example", "Missing in fenced code block")
end

results << if has_command_block?(code_blocks, USAGE_COMMAND_HINTS)
  check(:pass, "Usage command example", "Found in fenced code block")
else
  check(:fail, "Usage command example", "Missing in fenced code block")
end

if word_count > 1200
  has_toc = headings.any? { |heading| heading.match?(/^\#{2,6}\s+(?:table\s+of\s+contents|contents)\b/i) }
  if has_toc
    results << check(:pass, "Table of contents for long README", "Present")
  else
    severity = options[:strict] ? :fail : :warn
    results << check(severity, "Table of contents for long README", "Missing (#{word_count} words)")
  end
end

if options[:strict]
  has_contributing = headings.any? { |heading| heading.match?(/^\#{1,6}\s+contribut(?:e|ing)\b/i) }
  has_features = headings.any? { |heading| heading.match?(/^\#{1,6}\s+(?:features?|capabilities)\b/i) }

  results << (has_contributing ? check(:pass, "Contributing section", "Found") : check(:warn, "Contributing section", "Missing"))
  results << (has_features ? check(:pass, "Features/capabilities section", "Found") : check(:warn, "Features/capabilities section", "Missing"))
end

puts "GitHub README audit: #{file}"
puts "Word count: #{word_count}"
puts

labels = {pass: "PASS", warn: "WARN", fail: "FAIL"}
results.each do |result|
  puts "[#{labels.fetch(result.status)}] #{result.label} — #{result.details}"
end

exit((results.any? { |result| result.status == :fail }) ? 2 : 0)
