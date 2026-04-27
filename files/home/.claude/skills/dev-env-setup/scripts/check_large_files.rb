#!/usr/bin/env ruby

require "fileutils"
require "json"
require "open3"
require "tmpdir"

class LargeFileCheck
  LINE_LIMIT = 100
  SKIP_VALUE = "true"
  CODE_EXTENSIONS = %w[
    .bash .c .cc .clj .cljs .cpp .cs .css .cxx .dart .eex .erl .ex .exs .fish .fs .fsx
    .go .gemspec .h .haml .heex .hh .hpp .html .java .jl .js .jsx .kt .kts .less .lua .m
    .mjs .mm .php .pl .pm .py .pyw .r .rake .rb .rs .ru .sass .scala .scss .sh .slim .sql
    .svelte .swift .ts .tsx .vue .zsh
  ].freeze
  CODE_FILENAMES = %w[
    BUILD Containerfile Dockerfile Gemfile Guardfile Makefile Podfile Rakefile Vagrantfile WORKSPACE
  ].freeze

  def run
    if large_files_appropriate?
      puts "Skipping large file LOC check because LARGE_FILES_APPROPRIATE=true."
      return
    end

    large_files = large_staged_code_files
    return pass if large_files.empty?

    fail_with_large_files(large_files)
  end

  private

  def large_staged_code_files
    staged_files.select { |file| code_file?(file.fetch(:path)) }.filter_map { |file| large_file(file) }
  end

  def pass
    puts "No staged code files crossed #{LINE_LIMIT} lines of code."
  end

  def fail_with_large_files(large_files)
    warn "Staged changes make these code files cross from under #{LINE_LIMIT} to over #{LINE_LIMIT} lines of code:"
    large_files.each { |file| warn "  #{file[:path]} (#{file[:before]} -> #{file[:after]} LOC)" }
    warn "Don't do this unless absolutely appropriate for the domain."
    warn "Consider decomposing into multiple files."
    warn "To override this check, use LARGE_FILES_APPROPRIATE=true."
    exit 1
  end

  def large_file(file)
    before = code_lines_at("HEAD", file.fetch(:before_path))
    after = code_lines_at("", file.fetch(:path))
    return unless before < LINE_LIMIT && after > LINE_LIMIT

    {path: file.fetch(:path), before: before, after: after}
  end

  def staged_files
    output, status = Open3.capture2e("git", "diff", "--cached", "--name-status", "--diff-filter=ACMR", "-z")
    abort output unless status.success?

    parse_name_status(output.split("\0").reject(&:empty?))
  end

  def parse_name_status(tokens)
    files = []
    until tokens.empty?
      status = tokens.shift
      if status.start_with?("R", "C")
        before_path = tokens.shift
        path = tokens.shift
      else
        path = tokens.shift
        before_path = path
      end
      files << {path: path, before_path: before_path} if path
    end
    files
  end

  def code_file?(path)
    CODE_EXTENSIONS.include?(File.extname(path).downcase) || CODE_FILENAMES.include?(File.basename(path))
  end

  def code_lines_at(revision, path)
    blob = git_blob(revision, path)
    return 0 unless blob

    Dir.mktmpdir("large-file-check") do |dir|
      file_path = File.join(dir, path)
      FileUtils.mkdir_p(File.dirname(file_path))
      File.binwrite(file_path, blob)
      cloc_code_lines(file_path)
    end
  end

  def git_blob(revision, path)
    spec = revision.empty? ? ":#{path}" : "#{revision}:#{path}"
    output, status = Open3.capture2e("git", "show", spec)
    return unless status.success?

    output
  end

  def cloc_code_lines(path)
    output, status = Open3.capture2e("cloc", "--json", "--quiet", path)
    abort output unless status.success?

    cloc_report = JSON.parse(output)
    cloc_report.fetch("SUM", {}).fetch("code", 0)
  rescue JSON::ParserError => e
    abort "Could not parse cloc output for #{path}: #{e.message}"
  end

  def large_files_appropriate?
    ENV.fetch("LARGE_FILES_APPROPRIATE", "").casecmp?(SKIP_VALUE)
  end
end

LargeFileCheck.new.run
