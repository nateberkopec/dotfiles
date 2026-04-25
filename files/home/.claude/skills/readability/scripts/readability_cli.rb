# frozen_string_literal: true

require "open3"

class ReadabilityCli
  attr_reader :filename, :branch

  def initialize(argv, stdin)
    @filename = argv[0]
    @branch = argv[1]
    @stdin = stdin
  end

  def run
    current = analyze(current_text)
    return print_current(current) unless branch

    print_comparison(current)
  end

  private

  def current_text
    text = filename ? read_file(filename) : @stdin.read
    exit_with_error("No input provided.") if text.strip.empty?
    text
  end

  def read_file(path)
    exit_with_error("File not found: #{path}") unless File.exist?(path)

    File.read(path)
  end

  def print_comparison(current)
    baseline = analyze(branch_text)
    print_comparison_report(baseline, current)
  end

  def branch_text
    require_filename_for_branch
    text, status = Open3.capture2("git", "show", "#{branch}:#{filename}")
    exit_with_error("Could not read file from branch '#{branch}'") unless status.success? && !text.strip.empty?

    text
  end

  def require_filename_for_branch
    exit_with_error("Filename required for branch comparison") unless filename
  end

  def print_comparison_report(baseline, current)
    puts comparison_title
    puts "  #{branch}: #{output_format % baseline}"
    puts "  current: #{output_format % current}"
    puts "  improvement: #{output_format % comparison_delta(baseline, current)}"
  end

  def comparison_delta(baseline, current)
    current - baseline
  end

  def exit_with_error(message)
    warn message
    exit 1
  end
end
