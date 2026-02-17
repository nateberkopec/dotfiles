#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "pathname"

Rule = Struct.new(:source, :selector, :declarations)
Finding = Struct.new(:status, :message)

GENERIC_FAMILIES = %w[
  serif
  sans-serif
  monospace
  system-ui
  ui-serif
  ui-sans-serif
  ui-monospace
  cursive
  fantasy
  emoji
  math
  fangsong
].freeze

IL1_TEST_STRING = "IL1 il1 O0 5S 2Z rn m"

NAMED_COLORS = {
  "black" => [0, 0, 0],
  "white" => [255, 255, 255],
  "gray" => [128, 128, 128],
  "grey" => [128, 128, 128],
  "red" => [255, 0, 0],
  "green" => [0, 128, 0],
  "blue" => [0, 0, 255]
}.freeze

def usage_error(message)
  warn message
  warn "Usage: typography_audit.rb <file-or-glob> [more paths...] [--il1-html OUTFILE]"
  exit 1
end

def parse_css_rules(source, css)
  text = css.gsub(%r{/\*.*?\*/}m, "")

  text.scan(/([^{}]+)\{([^{}]*)\}/m).filter_map do |selector, body|
    declarations = body.split(";").each_with_object({}) do |entry, props|
      key, value = entry.split(":", 2)
      next if key.nil? || value.nil?

      prop = key.strip.downcase
      next if prop.empty?

      props[prop] = value.strip
    end

    next if declarations.empty?

    Rule.new(source, selector.strip, declarations)
  end
end

def extract_css(path)
  text = File.read(path)
  extension = File.extname(path).downcase

  if %w[.css .scss .sass .less].include?(extension)
    return [[path, text]]
  end

  style_blocks = text.scan(/<style\b[^>]*>(.*?)<\/style>/im).flatten
  return [] if style_blocks.empty?

  style_blocks.each_with_index.map do |block, index|
    ["#{path}:style[#{index + 1}]", block]
  end
end

def parse_px(value)
  return nil if value.nil?

  stripped = value.downcase.gsub("!important", "").strip
  match = stripped.match(/(-?\d*\.?\d+)\s*(px|rem|em|pt|%)?\b/)
  return nil unless match

  amount = match[1].to_f
  unit = match[2] || "px"

  case unit
  when "px" then amount
  when "rem", "em" then amount * 16
  when "pt" then amount * 96.0 / 72.0
  when "%" then amount * 16.0 / 100.0
  end
end

def parse_line_height_ratio(value, font_size_px)
  return nil if value.nil?

  cleaned = value.downcase.gsub("!important", "").strip
  return nil if cleaned == "normal"

  if cleaned.match?(/^\d*\.?\d+$/)
    return cleaned.to_f
  end

  if cleaned.end_with?("%")
    return cleaned.to_f / 100.0
  end

  line_height_px = parse_px(cleaned)
  return nil if line_height_px.nil? || font_size_px.nil? || font_size_px.zero?

  line_height_px / font_size_px
end

def parse_hex_color(token)
  value = token.delete_prefix("#")

  case value.length
  when 3
    value.chars.map { |char| (char * 2).to_i(16) }
  when 4
    value[0, 3].chars.map { |char| (char * 2).to_i(16) }
  when 6
    [value[0..1], value[2..3], value[4..5]].map { |pair| pair.to_i(16) }
  when 8
    [value[0..1], value[2..3], value[4..5]].map { |pair| pair.to_i(16) }
  end
end

def parse_rgb_color(token)
  match = token.match(/rgba?\(([^)]+)\)/i)
  return nil unless match

  channels = match[1].split(",").map(&:strip)
  return nil if channels.length < 3

  rgb = channels.first(3).map do |channel|
    if channel.end_with?("%")
      (channel.to_f * 2.55).round
    else
      channel.to_f.round
    end
  end

  (rgb.all? { |value| value.between?(0, 255) }) ? rgb : nil
end

def parse_color(raw)
  return nil if raw.nil?

  value = raw.downcase.gsub("!important", "")

  token = value[/#[0-9a-f]{3,8}\b/i]
  return parse_hex_color(token) unless token.nil?

  rgb = parse_rgb_color(value)
  return rgb unless rgb.nil?

  words = value.split(/[^a-z-]+/).reject(&:empty?)
  words.each do |word|
    named = NAMED_COLORS[word]
    return named unless named.nil?
  end

  nil
end

def relative_luminance(rgb)
  channels = rgb.map do |value|
    c = value / 255.0
    (c <= 0.03928) ? c / 12.92 : ((c + 0.055) / 1.055)**2.4
  end

  0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
end

def contrast_ratio(foreground, background)
  l1 = relative_luminance(foreground)
  l2 = relative_luminance(background)
  lighter = [l1, l2].max
  darker = [l1, l2].min
  (lighter + 0.05) / (darker + 0.05)
end

def clean_family_name(name)
  name.strip.delete_prefix('"').delete_suffix('"').delete_prefix("'").delete_suffix("'")
end

def add_finding(findings, status, source, selector, detail)
  findings << Finding.new(status, "#{source} :: #{selector} — #{detail}")
end

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: typography_audit.rb <file-or-glob> [more paths...] [--il1-html OUTFILE]"
  opts.on("--il1-html PATH", "Write an HTML IL1 specimen page for discovered fonts") { |value| options[:il1_html] = value }
end.parse!(ARGV)

usage_error("At least one path or glob is required") if ARGV.empty?

paths = ARGV.flat_map { |pattern| Dir.glob(pattern) }.uniq
usage_error("No files matched the provided paths") if paths.empty?

rules = []
paths.each do |path|
  next unless File.file?(path)

  extract_css(path).each do |source, css|
    rules.concat(parse_css_rules(source, css))
  end
end

usage_error("No CSS rules were found in the selected files") if rules.empty?

findings = []
font_families = []

rules.each do |rule|
  declarations = rule.declarations

  family = declarations["font-family"]
  unless family.nil?
    families = family.split(",").map { |entry| clean_family_name(entry) }.reject(&:empty?)
    font_families.concat(families)

    if family.match?(/condensed|narrow/i)
      add_finding(findings, :warn, rule.source, rule.selector, "Uses condensed/narrow family: #{family}")
    end
  end

  font_size_px = parse_px(declarations["font-size"])
  if !font_size_px.nil? && font_size_px < 14
    status = (font_size_px < 12) ? :fail : :warn
    add_finding(findings, status, rule.source, rule.selector, format("Small font-size %.1fpx", font_size_px))
  end

  line_height_ratio = parse_line_height_ratio(declarations["line-height"], font_size_px)
  if !line_height_ratio.nil? && line_height_ratio < 1.4
    status = (line_height_ratio < 1.2) ? :fail : :warn
    add_finding(findings, status, rule.source, rule.selector, format("Tight line-height ratio %.2f", line_height_ratio))
  end

  font_weight = declarations["font-weight"]&.downcase
  if !font_weight.nil? && font_weight.match?(/^(100|200|300|light)$/) && !font_size_px.nil? && font_size_px < 16
    add_finding(findings, :warn, rule.source, rule.selector, "Thin/light weight at small size can hurt glanceability")
  end

  text_color = parse_color(declarations["color"])
  background = parse_color(declarations["background-color"]) || parse_color(declarations["background"])
  unless text_color.nil? || background.nil?
    ratio = contrast_ratio(text_color, background)
    if ratio < 4.5
      status = (ratio < 3) ? :fail : :warn
      add_finding(findings, status, rule.source, rule.selector, format("Low contrast %.2f:1", ratio))
    end
  end
end

non_generic_families = font_families.uniq.reject { |name| GENERIC_FAMILIES.include?(name.downcase) }
if non_generic_families.size > 2
  status = (non_generic_families.size > 3) ? :fail : :warn
  findings << Finding.new(status, "Global — Uses #{non_generic_families.size} non-generic font families (#{non_generic_families.join(", ")})")
end

link_rules = rules.select { |rule| rule.selector.match?(/\ba\b/) }
unless link_rules.empty?
  has_visited_color = link_rules.any? do |rule|
    rule.selector.include?(":visited") && rule.declarations.key?("color")
  end

  if !has_visited_color
    findings << Finding.new(:warn, "Global — No :visited color style detected for links")
  end

  base_link_without_underline = link_rules.any? do |rule|
    rule.selector.match?(/\ba\b/) && !rule.selector.include?(":") && rule.declarations["text-decoration"]&.match?(/none/i)
  end

  hover_recovers_underline = link_rules.any? do |rule|
    rule.selector.include?(":hover") && rule.declarations["text-decoration"]&.match?(/underline/i)
  end

  has_underlined_links = link_rules.any? do |rule|
    rule.declarations["text-decoration"]&.match?(/underline/i)
  end

  if base_link_without_underline && !hover_recovers_underline && !has_underlined_links
    findings << Finding.new(:fail, "Global — Links remove underlines without restoring a clear hover/focus cue")
  end
end

status_order = {fail: 0, warn: 1, pass: 2}
findings.sort_by! { |finding| [status_order.fetch(finding.status), finding.message] }

puts "Typography audit"
puts "  Files scanned: #{paths.size}"
puts "  CSS rules scanned: #{rules.size}"
puts "  Font families found: #{font_families.uniq.join(", ")}"
puts

if findings.empty?
  puts "No issues found by heuristic checks."
  puts "Remember to run a manual IL1 check for critical alphanumeric UI."
else
  labels = {fail: "FAIL", warn: "WARN", pass: "PASS"}
  findings.each do |finding|
    puts "[#{labels.fetch(finding.status)}] #{finding.message}"
  end
end

puts
puts "IL1 quick test string: #{IL1_TEST_STRING}"
puts "Use this string when visually comparing candidate fonts for alphanumeric UI."

if options[:il1_html]
  specimen_fonts = (non_generic_families + GENERIC_FAMILIES.first(2)).uniq
  html = <<~HTML
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>IL1 Typography Specimen</title>
        <style>
          body { font-family: system-ui, sans-serif; margin: 2rem; line-height: 1.5; }
          .sample { margin: 1rem 0; padding: 0.75rem 1rem; border: 1px solid #ddd; }
          .family { font-size: 0.9rem; color: #555; margin-bottom: 0.5rem; }
          .text { font-size: 1.5rem; letter-spacing: 0.02em; }
        </style>
      </head>
      <body>
        <h1>IL1 Typography Specimen</h1>
        <p>Test string: <strong>#{IL1_TEST_STRING}</strong></p>
        #{specimen_fonts.map { |family| "<div class=\"sample\"><div class=\"family\">#{family}</div><div class=\"text\" style=\"font-family: #{family};\">#{IL1_TEST_STRING}</div></div>" }.join("\n")}
      </body>
    </html>
  HTML

  File.write(options[:il1_html], html)
  puts "Wrote IL1 specimen: #{options[:il1_html]}"
end

exit((findings.any? { |finding| finding.status == :fail }) ? 2 : 0)
