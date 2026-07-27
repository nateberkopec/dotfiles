# frozen_string_literal: true

module MarkdownProse
  module_function

  def structural_text(text)
    cleaned = text.gsub(/<pre\b.*?<\/pre>|<code\b.*?<\/code>/im, "\n")
    output = []
    fence = nil
    cleaned.each_line do |line|
      if fence
        fence = nil if line.match?(/^\s{0,3}#{Regexp.escape(fence[0])}{#{fence.length},}\s*$/)
      elsif (opening = line.match(/^\s{0,3}(`{3,}|~{3,})/))
        fence = opening[1]
      else
        output << line unless line.match?(/^(?: {4}|\t)\S/)
      end
    end
    output.join
  end

  def blocks(text)
    cleaned = text.gsub(/<pre\b.*?<\/pre>|<code\b.*?<\/code>/im, "\n")
    output = []
    paragraph = []
    fence = nil

    flush = lambda do
      output << paragraph.join(" ").strip unless paragraph.empty?
      paragraph.clear
    end
    cleaned.each_line do |line|
      if fence
        fence = nil if line.match?(/^\s{0,3}#{Regexp.escape(fence[0])}{#{fence.length},}\s*$/)
        next
      end
      if (opening = line.match(/^\s{0,3}(`{3,}|~{3,})/))
        flush.call
        fence = opening[1]
      elsif line.match?(/^(?: {4}|\t)\S/)
        flush.call
      elsif line.match?(/^\s{0,3}\#{1,6}\s+/)
        flush.call
      elsif (item = line.match(/^\s*(?:[-*+] |\d+[.)] )(.*)$/))
        flush.call
        output << strip_markup(item[1]).strip unless item[1].strip.empty?
      elsif line.strip.empty?
        flush.call
      else
        paragraph << strip_markup(line)
      end
    end
    flush.call
    output
  end

  def words(text)
    blocks(text).join(" ").scan(/[A-Za-z0-9']+/)
  end

  def sentences(text)
    blocks(text).flat_map do |block|
      parts = block.split(/(?<=[.!?])(?:(?:\x5D|[)"'])*)\s+/).map(&:strip).reject(&:empty?)
      parts.empty? ? [block] : parts
    end
  end

  def strip_markup(text)
    text.gsub(/<[^>]+>/, " ").gsub(/!?\[(.*?)\]\([^)]*\)/, "\\1")
      .gsub(/[`*_~]/, " ")
  end
end
