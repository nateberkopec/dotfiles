#!/usr/bin/env ruby
require_relative "dependency_factory"
require "json"
require "yaml"

candidates_path, report_path, base, notes_path, starting_head = ARGV
starting_head ||= base
abort "Usage: check_dependency_report.rb CANDIDATES_JSON REPORT_MD BASE_SHA NOTES_JSON" unless notes_path
abort "Expected a commit SHA" unless [base, starting_head].all? { |sha| sha.match?(/\A[0-9a-f]{40}\z/) }
candidates = JSON.parse(File.read(candidates_path))
report = DependencyFactory::Report.new(File.read(report_path))
changes = DependencyFactory::ChangedPins.new(base: base, root: Dir.pwd).changes
snoozes = YAML.safe_load_file(DependencyFactory::CONFIG_PATH).fetch("snoozes", nil) || {}
original = YAML.safe_load(DependencyFactory::Sources.capture({}, "git", "show", "#{starting_head}:#{DependencyFactory::CONFIG_PATH}")).fetch("snoozes", nil) || {}
notes = JSON.parse(File.read(notes_path))
errors = DependencyFactory::ReportChecks.new(candidates: candidates, report: report, changes: changes, snoozes: snoozes, notes: notes, original_snoozes: original).errors
errors.each { |error| warn "✗ #{error}" }
abort "#{errors.size} dependency report problem(s)" unless errors.empty?
puts "Dependency report covers #{candidates["candidates"].size} candidate(s) and matches the diff"
