#!/usr/bin/env ruby
# frozen_string_literal: true

# Flesch-Kincaid Grade Level Calculator
# Usage: flesch_kincaid.rb [filename] [branch]
#   - If no arguments: reads from STDIN
#   - If filename only: analyzes that file
#   - If filename and branch: compares current file to version in branch

require_relative "readability_cli"
require_relative "markdown_prose"

class FleschKincaidCalculator
  def grade_level(text)
    words = MarkdownProse.words(text)
    return 0.0 if words.empty?

    grade_formula(words.length.to_f / [MarkdownProse.sentences(text).length, 1].max, syllables_per_word(words))
  end

  private

  def syllables_per_word(words)
    syllable_count(words).to_f / words.length
  end

  def grade_formula(words_per_sentence, syllables_per_word)
    0.39 * words_per_sentence + 11.8 * syllables_per_word - 15.59
  end

  def syllable_count(words)
    words.sum { |word| syllables_in(word) }
  end

  def syllables_in(word)
    token = word.downcase.gsub(/[^a-z]/, "")
    return 0 if token.empty?

    token = token.sub(/e$/, "") unless token.match?(/le$/) && token.length > 2
    [token.scan(/[aeiouy]+/).length, 1].max
  end
end

class FleschKincaidCli < ReadabilityCli
  private

  def analyze(text)
    @calculator ||= FleschKincaidCalculator.new
    @calculator.grade_level(text)
  end

  def print_current(grade)
    puts "Flesch-Kincaid Grade Level: %.1f" % grade
  end

  def comparison_title
    "Flesch-Kincaid Grade Level Comparison"
  end

  def comparison_delta(baseline, current)
    baseline - current
  end

  def output_format
    "%.1f"
  end
end

FleschKincaidCli.new(ARGV, $stdin).run if $PROGRAM_NAME == __FILE__
