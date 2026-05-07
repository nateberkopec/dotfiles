#!/usr/bin/env ruby

require "json"
require "open3"

class DeadCodeCheck
  SOURCE_PATHS = %w[app lib tools rubocop rakelib Rakefile].freeze
  RUBY_SHEBANG_DIRS = %w[bin exe script scripts].freeze
  WHITELIST_PATH = ".debride-whitelist"

  WhitelistEntry = Struct.new(:raw) do
    def self.parse(line)
      value = line.strip
      return if value.empty? || value.start_with?("#")
      new(value)
    end

    def match?(name)
      regex ? regex.match?(name) : raw == name
    end

    def regex
      @regex ||= Regexp.new(raw[1..-2]) if raw.match?(/\A\/.+\/\z/)
    end
  end

  def run
    missing, unused_whitelist = analyze
    return pass if missing.empty? && unused_whitelist.empty?

    report_missing(missing) unless missing.empty?
    report_unused_whitelist(unused_whitelist) unless unused_whitelist.empty?
    exit 1
  rescue JSON::ParserError => e
    abort "Could not parse debride output: #{e.message}"
  end

  private

  def analyze
    whitelist = load_whitelist
    used_whitelist = []
    missing = JSON.parse(debride_output).fetch("missing")
    missing = filter_whitelisted(missing, whitelist, used_whitelist)
    [missing, whitelist.reject { |entry| used_whitelist.include?(entry) }]
  end

  def pass
    puts "No dead Ruby methods detected."
  end

  def filter_whitelisted(missing, whitelist, used_whitelist)
    missing.transform_values do |methods|
      methods.reject do |name, _location|
        entry = whitelist.find { |candidate| candidate.match?(name) }
        used_whitelist << entry if entry && !used_whitelist.include?(entry)
        entry
      end
    end.reject { |_, methods| methods.empty? }
  end

  def load_whitelist
    return [] unless File.exist?(WHITELIST_PATH)
    File.readlines(WHITELIST_PATH).filter_map { |line| WhitelistEntry.parse(line) }
  end

  def report_missing(missing)
    warn "Debride found potentially dead Ruby methods:"
    missing.each do |owner, methods|
      warn "\n#{owner}"
      methods.each { |name, location| warn "  #{name} #{location}" }
    end
    warn "\nRemove these methods or add intentional false positives to #{WHITELIST_PATH}."
  end

  def report_unused_whitelist(unused_whitelist)
    warn "\n#{WHITELIST_PATH} contains unused entries:"
    unused_whitelist.each { |entry| warn "  #{entry.raw}" }
    warn "\nRemove stale whitelist entries."
  end

  def debride_output
    output, status = Open3.capture2e("bundle", "exec", "debride", "--json", *source_paths)
    abort output unless status.success?
    output
  end

  def source_paths
    SOURCE_PATHS.select { |path| File.exist?(path) } + ruby_shebang_files
  end

  def ruby_shebang_files
    RUBY_SHEBANG_DIRS.flat_map do |dir|
      Dir.glob(File.join(dir, "*")).select { |path| ruby_shebang?(path) }
    end.uniq
  end

  def ruby_shebang?(path)
    File.file?(path) && File.open(path, &:readline).include?("ruby")
  rescue EOFError
    false
  end
end

DeadCodeCheck.new.run if $PROGRAM_NAME == __FILE__
