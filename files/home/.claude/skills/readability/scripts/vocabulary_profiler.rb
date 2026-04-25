#!/usr/bin/env ruby
# frozen_string_literal: true

# Vocabulary Profiler
# Usage: vocabulary_profiler.rb [filename] [branch]
#   - If no arguments: reads from STDIN
#   - If filename only: analyzes that file
#   - If filename and branch: compares current file to version in branch
# Word list from: https://simple.wikipedia.org/wiki/Wikipedia:List_of_1000_basic_words

require_relative "readability_cli"

class VocabularyProfiler
  def initialize(word_list_path)
    @basic_words = File.readlines(word_list_path, chomp: true).to_set.freeze
  end

  def top1000_percentage(text)
    words = extract_words(strip_code_blocks(text))
    return 0.0 if words.empty?

    basic_words = words.count { |word| @basic_words.include?(word) }
    basic_words.to_f / words.length * 100
  end

  private

  def strip_code_blocks(text)
    text.gsub(/```.*?```/m, "")
  end

  def extract_words(text)
    text.downcase.scan(/[a-z]+/)
  end
end

class VocabularyProfilerCli < ReadabilityCli
  WORD_LIST_PATH = File.expand_path("top1000.txt", __dir__)

  private

  def analyze(text)
    @profiler ||= VocabularyProfiler.new(WORD_LIST_PATH)
    @profiler.top1000_percentage(text)
  end

  def print_current(percentage)
    puts "Words in top 1000: %.1f%%" % percentage
  end

  def comparison_title
    "Top 1000 Words Comparison"
  end

  def output_format
    "%.1f%%"
  end
end

VocabularyProfilerCli.new(ARGV, $stdin).run
