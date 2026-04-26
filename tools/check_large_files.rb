#!/usr/bin/env ruby

require "open3"

class LargeFileCheck
  DEFAULT_LIMIT_BYTES = 1_048_576

  def run
    oversized_files = staged_paths.filter_map { |path| oversized_file(path) }
    if oversized_files.empty?
      puts "No staged files exceed #{formatted_size(limit_bytes)}."
      return
    end

    warn "Staged files exceed #{formatted_size(limit_bytes)}:"
    oversized_files.each do |file|
      warn "  #{file[:path]} (#{formatted_size(file[:size])})"
    end
    warn "Move large assets to external storage or raise LARGE_FILE_LIMIT_BYTES intentionally."
    exit 1
  end

  private

  def oversized_file(path)
    size = staged_blob_size(path)
    return unless size && size > limit_bytes

    {path: path, size: size}
  end

  def staged_paths
    output, status = Open3.capture2e("git", "diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z")
    abort output unless status.success?

    output.split("\0").reject(&:empty?)
  end

  def staged_blob_size(path)
    output, status = Open3.capture2e("git", "cat-file", "-s", ":#{path}")
    return unless status.success?

    output.to_i
  end

  def limit_bytes
    @limit_bytes ||= begin
      configured_limit = ENV.fetch("LARGE_FILE_LIMIT_BYTES", DEFAULT_LIMIT_BYTES).to_i
      configured_limit.positive? ? configured_limit : DEFAULT_LIMIT_BYTES
    end
  end

  def formatted_size(size)
    units = ["B", "KiB", "MiB", "GiB"]
    value = size.to_f
    unit = units.first

    units.each do |candidate_unit|
      unit = candidate_unit
      break if value < 1024 || candidate_unit == units.last

      value /= 1024
    end

    format("%.1f %s", value, unit)
  end
end

LargeFileCheck.new.run
