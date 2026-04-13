#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "open3"

class ReadabilityAudit
  LONG_SENTENCE_WORDS = 25
  LONG_PARAGRAPH_WORDS = 120

  CheckResult = Struct.new(:status, :label, :details)

  def initialize(text)
    @original_text = text
    @normalized_text = normalize_text(text)
  end

  def metrics
    @metrics ||= begin
      words = extract_words(@normalized_text)
      sentences = extract_sentences(@normalized_text)
      paragraphs = extract_paragraphs(@normalized_text)

      sentence_lengths = sentences.map { |sentence| extract_words(sentence).size }
      paragraph_lengths = paragraphs.map { |paragraph| extract_words(paragraph).size }

      {
        words: words.size,
        sentences: [sentences.size, 1].max,
        paragraphs: [paragraphs.size, 1].max,
        heading_count: heading_count(@original_text),
        list_item_count: list_item_count(@original_text),
        avg_words_per_sentence: average(sentence_lengths),
        avg_words_per_paragraph: average(paragraph_lengths),
        long_sentence_ratio: ratio(sentence_lengths.count { |count| count > LONG_SENTENCE_WORDS }, sentence_lengths.size),
        long_paragraph_ratio: ratio(paragraph_lengths.count { |count| count > LONG_PARAGRAPH_WORDS }, paragraph_lengths.size),
        first_paragraph_words: paragraph_lengths.first || 0,
        flesch_kincaid_grade: flesch_kincaid_grade(words, sentences)
      }
    end
  end

  def checks(target_grade: 10)
    m = metrics
    results = []

    results << threshold_check(
      m[:flesch_kincaid_grade],
      label: "Flesch-Kincaid grade <= #{target_grade}",
      display_value: format("%.1f", m[:flesch_kincaid_grade]),
      max: target_grade
    )

    results << threshold_check(
      m[:avg_words_per_sentence],
      label: "Average sentence length <= 20 words",
      display_value: format("%.1f", m[:avg_words_per_sentence]),
      max: 20
    )

    results << threshold_check(
      m[:long_sentence_ratio],
      label: "Long-sentence ratio <= 15%",
      display_value: percent(m[:long_sentence_ratio]),
      max: 0.15
    )

    results << threshold_check(
      m[:long_paragraph_ratio],
      label: "Long-paragraph ratio <= 20%",
      display_value: percent(m[:long_paragraph_ratio]),
      max: 0.20
    )

    results << threshold_check(
      m[:first_paragraph_words],
      label: "Lead paragraph <= 60 words",
      display_value: m[:first_paragraph_words].to_s,
      max: 60,
      warning_max: 90
    )

    if m[:words] >= 600
      minimum_headings = (m[:words] / 300.0).ceil
      results << threshold_check(
        m[:heading_count],
        label: "Heading density (>= 1 heading / 300 words)",
        display_value: "#{m[:heading_count]} headings for #{m[:words]} words",
        min: minimum_headings
      )
    end

    if m[:words] >= 400
      results << threshold_check(
        m[:list_item_count],
        label: "At least one bulleted or numbered list for long content",
        display_value: m[:list_item_count].to_s,
        min: 1
      )
    end

    results
  end

  private

  def normalize_text(text)
    cleaned = text.dup
    cleaned = strip_markdown_code_blocks(cleaned)
    cleaned = strip_html_code_blocks(cleaned)
    cleaned = strip_html_tags(cleaned)
    cleaned.gsub(/\r\n?/, "\n")
  end

  def strip_markdown_code_blocks(text)
    text
      .gsub(/```.*?```/m, "")
      .gsub(/^ {4}.*$/, "")
  end

  def strip_html_code_blocks(text)
    text
      .gsub(/<pre\b.*?<\/pre>/im, " ")
      .gsub(/<code\b.*?<\/code>/im, " ")
  end

  def strip_html_tags(text)
    text.gsub(/<[^>]+>/, " ")
  end

  def extract_words(text)
    text.scan(/[A-Za-z0-9']+/)
  end

  def extract_sentences(text)
    sentences = text
      .gsub(/\n+/, " ")
      .split(/(?<=[.!?])\s+/)
      .map(&:strip)
      .reject(&:empty?)

    sentences.empty? ? [text] : sentences
  end

  def extract_paragraphs(text)
    paragraphs = text
      .split(/\n\s*\n+/)
      .map(&:strip)
      .reject(&:empty?)

    paragraphs.empty? ? [text] : paragraphs
  end

  def heading_count(text)
    markdown = text.scan(/^\s{0,3}\#{1,6}\s+.+$/).size
    html = text.scan(/<h[1-6][^>]*>/i).size
    markdown + html
  end

  def list_item_count(text)
    markdown = text.scan(/^\s*(?:[-*+]\s+|\d+[.)]\s+)/).size
    html = text.scan(/<li\b/i).size
    markdown + html
  end

  def flesch_kincaid_grade(words, sentences)
    word_count = words.size
    return 0.0 if word_count.zero?

    syllable_count = words.sum { |word| count_syllables(word) }
    sentence_count = [sentences.size, 1].max

    0.39 * (word_count.to_f / sentence_count) +
      11.8 * (syllable_count.to_f / word_count) -
      15.59
  end

  def count_syllables(word)
    token = word.downcase.gsub(/[^a-z]/, "")
    return 0 if token.empty?

    token = token.sub(/e$/, "") unless token.match?(/le$/) && token.length > 2
    groups = token.scan(/[aeiouy]+/).size
    [groups, 1].max
  end

  def average(values)
    return 0.0 if values.empty?

    values.sum.to_f / values.size
  end

  def ratio(numerator, denominator)
    return 0.0 if denominator.nil? || denominator.zero?

    numerator.to_f / denominator
  end

  def percent(value)
    format("%.1f%%", value * 100)
  end

  def threshold_check(metric_value, label:, display_value:, min: nil, max: nil, warning_max: nil)
    if !min.nil? && metric_value.to_f < min.to_f
      return CheckResult.new(:fail, label, "#{display_value} (minimum #{min})")
    end

    if !max.nil? && metric_value.to_f > max.to_f
      status = (warning_max && metric_value.to_f <= warning_max.to_f) ? :warn : :fail
      return CheckResult.new(status, label, "#{display_value} (maximum #{max})")
    end

    CheckResult.new(:pass, label, display_value)
  end
end

def usage_error(message)
  warn message
  warn "Usage: readability_audit.rb <file> [--branch BRANCH] [--target-grade N]"
  exit 1
end

options = {target_grade: 10.0}

OptionParser.new do |opts|
  opts.banner = "Usage: readability_audit.rb <file> [--branch BRANCH] [--target-grade N]"
  opts.on("--branch BRANCH", "Compare against a git branch version of the same file") { |value| options[:branch] = value }
  opts.on("--target-grade N", Float, "Target max Flesch-Kincaid grade (default: 10)") { |value| options[:target_grade] = value }
end.parse!(ARGV)

file = ARGV.shift
usage_error("Missing file path") if file.nil?
usage_error("File not found: #{file}") unless File.exist?(file)

text = File.read(file)
audit = ReadabilityAudit.new(text)
metrics = audit.metrics
checks = audit.checks(target_grade: options[:target_grade])

puts "Readability audit: #{file}"
puts
puts "Metrics"
puts "  Words: #{metrics[:words]}"
puts "  Sentences: #{metrics[:sentences]}"
puts "  Paragraphs: #{metrics[:paragraphs]}"
puts format("  Flesch-Kincaid grade: %.1f", metrics[:flesch_kincaid_grade])
puts format("  Avg words/sentence: %.1f", metrics[:avg_words_per_sentence])
puts format("  Avg words/paragraph: %.1f", metrics[:avg_words_per_paragraph])
puts "  Long sentences (>#{ReadabilityAudit::LONG_SENTENCE_WORDS} words): #{format("%.1f%%", metrics[:long_sentence_ratio] * 100)}"
puts "  Long paragraphs (>#{ReadabilityAudit::LONG_PARAGRAPH_WORDS} words): #{format("%.1f%%", metrics[:long_paragraph_ratio] * 100)}"
puts "  Headings: #{metrics[:heading_count]}"
puts "  List items: #{metrics[:list_item_count]}"
puts
puts "Checks"

status_labels = {pass: "PASS", warn: "WARN", fail: "FAIL"}
checks.each do |check|
  puts "  [#{status_labels.fetch(check.status)}] #{check.label} — #{check.details}"
end

if options[:branch]
  baseline_text, status = Open3.capture2("git", "show", "#{options[:branch]}:#{file}")

  if status.success? && !baseline_text.strip.empty?
    baseline = ReadabilityAudit.new(baseline_text).metrics

    puts
    puts "Comparison to #{options[:branch]}"
    puts format("  Grade change: %+.1f", metrics[:flesch_kincaid_grade] - baseline[:flesch_kincaid_grade])
    puts format("  Sentence-length change: %+.1f words", metrics[:avg_words_per_sentence] - baseline[:avg_words_per_sentence])
    puts format("  Long-sentence change: %+.1f%%", (metrics[:long_sentence_ratio] - baseline[:long_sentence_ratio]) * 100)
    puts format("  Long-paragraph change: %+.1f%%", (metrics[:long_paragraph_ratio] - baseline[:long_paragraph_ratio]) * 100)
  else
    puts
    puts "Comparison skipped: could not read #{file} from #{options[:branch]}"
  end
end

exit((checks.any? { |check| check.status == :fail }) ? 2 : 0)
