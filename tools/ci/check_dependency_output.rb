#!/usr/bin/env ruby
require_relative "dependency_factory"
require "json"

# Validate the exact safe-output body on both creation and revision, before publishing.
directory = ARGV.fetch(0, "/tmp/gh-aw/agent")
items = JSON.parse(File.read(File.join(directory, "../agent_output.json"))).fetch("items")
outcomes = %w[create_pull_request push_to_pull_request_branch update_pull_request add_comment]
abort "The agent finished without a pull request outcome" unless items.any? { |item| outcomes.include?(item["type"]) }
bodies = items.select { |item| %w[create_pull_request update_pull_request].include?(item["type"]) }
pushed = items.any? { |item| item["type"] == "push_to_pull_request_branch" }
abort "A branch push requires a refreshed pull request body" if pushed && bodies.empty?
exit if bodies.empty?
abort "Expected exactly one pull request body" unless bodies.size == 1
item = bodies.first
abort "The pull request body must replace, not append" unless item.fetch("operation", "replace") == "replace"
abort "The pull request body is empty" if item["body"].to_s.strip.empty?
context = JSON.parse(File.read(File.join(directory, "pr-context.json")))
if context["number"]
  targets = item.values_at("pull_request_number", "pr_number", "pr").compact
  abort "Update the triggering pull request only" unless item["type"] == "update_pull_request" && targets.all? { |number| number.to_s == context["number"].to_s }
  abort "Changed checkout requires a branch push" unless pushed || system("git", "diff", "--quiet", context.fetch("head"), "--")
else
  abort "No triggering pull request to update" unless item["type"] == "create_pull_request"
end
body_path = File.join(directory, "pr-body.md")
File.write(body_path, item.fetch("body"))
checker = File.join(__dir__, "check_dependency_report.rb")
abort "Dependency report failed validation" unless system("bundle", "exec", "ruby", checker, File.join(directory, "dependency-candidates.json"), body_path, context.fetch("base"), File.join(directory, "release-notes.json"))
abort "Commit checkout changes before publishing" unless system("git", "diff", "--quiet", "HEAD", "--")
items.select { |entry| %w[create_pull_request push_to_pull_request_branch].include?(entry["type"]) }.each do |entry|
  errors = DependencyFactory::Transport.errors(entry, directory: directory)
  abort errors.join("\n") unless errors.empty?
end
