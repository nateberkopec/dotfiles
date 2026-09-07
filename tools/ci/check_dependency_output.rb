#!/usr/bin/env ruby
require_relative "dependency_factory"
require "json"

# Gate exact safe outputs, not a draft body. Runs from the immutable workflow revision.
directory = ARGV.fetch(0, "/tmp/gh-aw/agent")
items = JSON.parse(File.read(File.join(directory, "../agent_output.json"))).fetch("items")
context = JSON.parse(File.read(File.join(directory, "pr-context.json")))
abort "Branch updates require a validated bundle, not update_branch" if items.any? { |item| item.key?("update_branch") }
outcomes = %w[create_pull_request push_to_pull_request_branch update_pull_request add_comment noop missing_data report_incomplete]
abort "The agent finished without an explicit outcome" unless items.any? { |item| outcomes.include?(item["type"]) }
items.select { |item| item["type"] == "add_comment" }.each do |item|
  targets = item.values_at("item_number", "issue_number", "pull_request_number").compact.map(&:to_s)
  allowed = context.values_at("number", "issue").compact.map(&:to_s).reject(&:empty?)
  abort "Comment must target the active batch or triggering issue" if targets.empty? || !(targets - allowed).empty?
end
bodies = items.select { |item| %w[create_pull_request update_pull_request].include?(item["type"]) }
pushed = items.any? { |item| item["type"] == "push_to_pull_request_branch" }
abort "A branch push requires a refreshed pull request body" if pushed && bodies.empty?
if bodies.empty?
  abort "No-change outcome has unpublished changes" unless system("git", "diff", "--quiet", context["head"] || context.fetch("base"), "--")
  exit
end
abort "Expected exactly one pull request body" unless bodies.size == 1
item = bodies.first
abort "The pull request body must replace, not append" unless item.fetch("operation", "replace") == "replace"
abort "The pull request body is empty" if item["body"].to_s.strip.empty?
if context["number"]
  targets = items.select { |entry| %w[update_pull_request push_to_pull_request_branch].include?(entry["type"]) }.flat_map { |entry| entry.values_at("pull_request_number", "pr_number", "pr").compact }
  abort "Update the active pull request only" unless item["type"] == "update_pull_request" && !targets.empty? && targets.all? { |number| number.to_s == context["number"].to_s }
  remote = DependencyFactory::Sources.capture({}, "gh", "api", "repos/#{ENV.fetch("GITHUB_REPOSITORY")}/pulls/#{context["number"]}", "--jq", ".head.sha").strip
  abort "PR head changed during this run" unless remote == context.fetch("head")
  abort "Changed checkout requires a branch push" unless pushed || system("git", "diff", "--quiet", context.fetch("head"), "--")
else
  abort "No active pull request to update" unless item["type"] == "create_pull_request"
end
body_path = File.join(directory, "pr-body.md")
File.write(body_path, item.fetch("body"))
checker = File.join(__dir__, "check_dependency_report.rb")
abort "Dependency report failed validation" unless system("bundle", "exec", "ruby", checker, File.join(directory, "dependency-candidates.json"), body_path, context.fetch("base"), File.join(directory, "release-notes.json"), context["head"] || context.fetch("base"))
abort "Commit checkout changes before publishing" unless system("git", "diff", "--quiet", "HEAD", "--")
abort "Mechanical boundary failed" unless system("bundle", "exec", "ruby", File.join(__dir__, "check_dependency_update.rb"), context.fetch("base"))
items.select { |entry| %w[create_pull_request push_to_pull_request_branch].include?(entry["type"]) }.each do |entry|
  errors = DependencyFactory::Transport.errors(entry, directory: directory)
  abort errors.join("\n") unless errors.empty?
end
