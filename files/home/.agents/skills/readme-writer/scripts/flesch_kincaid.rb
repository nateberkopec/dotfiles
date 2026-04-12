#!/usr/bin/env ruby
# frozen_string_literal: true

# Flesch-Kincaid Grade Level Calculator
# Usage: flesch_kincaid.rb [filename] [branch]
#   - If no arguments: reads from STDIN
#   - If filename only: analyzes that file
#   - If filename and branch: compares current file to version in branch

def strip_code_blocks(text)
  # Remove markdown code blocks (```...```)
  text.gsub(/```.*?```/m, "")
end

def count_syllables(word)
  word = word.downcase.gsub(/[^a-z]/, "")
  return 0 if word.empty?

  # Handle special endings
  word = word.sub(/e$/, "") unless word.match?(/le$/) && word.length > 2

  # Count vowel groups
  syllables = word.scan(/[aeiouy]+/).length

  # Every word has at least one syllable
  [syllables, 1].max
end

def count_sentences(text)
  # Count sentence-ending punctuation
  count = text.scan(/[.!?]+/).length
  [count, 1].max
end

def count_words(text)
  text.split(/\s+/).count { |w| !w.gsub(/[^a-zA-Z]/, "").empty? }
end

def extract_words(text)
  text.split(/\s+/).map { |w| w.gsub(/[^a-zA-Z]/, "") }.reject(&:empty?)
end

def flesch_kincaid_grade_level(text)
  text = strip_code_blocks(text)
  words = extract_words(text)
  word_count = words.length
  sentence_count = count_sentences(text)
  syllable_count = words.sum { |w| count_syllables(w) }

  return 0 if word_count.zero?

  0.39 * (word_count.to_f / sentence_count) +
    11.8 * (syllable_count.to_f / word_count) -
    15.59
end

def get_file_from_branch(filename, branch)
  `git show #{branch}:#{filename} 2>/dev/null`
end

# Parse arguments
filename = ARGV[0]
compare_branch = ARGV[1]

# Get current text
if filename
  unless File.exist?(filename)
    warn "File not found: #{filename}"
    exit 1
  end
  current_text = File.read(filename)
else
  current_text = $stdin.read
end

if current_text.strip.empty?
  warn "No input provided."
  exit 1
end

current_grade = flesch_kincaid_grade_level(current_text)

# If comparing to a branch
if compare_branch
  unless filename
    warn "Filename required for branch comparison"
    exit 1
  end

  baseline_text = get_file_from_branch(filename, compare_branch)

  if baseline_text.strip.empty?
    warn "Could not read file from branch '#{compare_branch}'"
    exit 1
  end

  baseline_grade = flesch_kincaid_grade_level(baseline_text)
  improvement = baseline_grade - current_grade

  puts "Flesch-Kincaid Grade Level Comparison"
  puts "  #{compare_branch}: %.1f" % baseline_grade
  puts "  current: %.1f" % current_grade
  puts "  improvement: %+.1f" % improvement
else
  puts "Flesch-Kincaid Grade Level: %.1f" % current_grade
end
