#!/usr/bin/env ruby
# frozen_string_literal: true

# Flesch-Kincaid Grade Level Calculator
# Reads text from STDIN and outputs the grade level

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
  words = extract_words(text)
  word_count = words.length
  sentence_count = count_sentences(text)
  syllable_count = words.sum { |w| count_syllables(w) }

  return 0 if word_count.zero?

  0.39 * (word_count.to_f / sentence_count) +
    11.8 * (syllable_count.to_f / word_count) -
    15.59
end

text = $stdin.read

if text.strip.empty?
  warn "No input provided. Please pipe text to this script."
  exit 1
end

grade_level = flesch_kincaid_grade_level(text)
puts format("Flesch-Kincaid Grade Level: %.1f", grade_level)
