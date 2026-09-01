#!/usr/bin/env ruby
require_relative "dependency_factory"
require "json"
require "yaml"

candidates_path, report_path, base = ARGV
abort "Usage: check_dependency_report.rb CANDIDATES_JSON REPORT_MD BASE_SHA" unless base
abort "Expected a commit SHA" unless base.match?(/\A[0-9a-f]{40}\z/)
candidates = JSON.parse(File.read(candidates_path))
report = DependencyFactory::Report.new(File.read(report_path))
changes = DependencyFactory::ChangedPins.new(base: base).changes
snoozes = YAML.safe_load_file(File.join(DependencyFactory::ROOT, DependencyFactory::CONFIG_PATH)).fetch("snoozes", nil) || {}
errors = DependencyFactory::RubricChecks.new(report: report).errors +
  DependencyFactory::ReportChecks.new(candidates: candidates, report: report, changes: changes, snoozes: snoozes).errors
errors.each { |error| warn "✗ #{error}" }
abort "#{errors.size} dependency report problem(s)" unless errors.empty?
puts "Dependency report covers #{candidates["candidates"].size} candidate(s) and matches the diff"
