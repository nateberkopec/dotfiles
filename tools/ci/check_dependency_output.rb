#!/usr/bin/env ruby
require_relative "dependency_factory"
require "json"
require "open3"

# Validate the exact safe-output body on both creation and revision, before publishing.
directory = ARGV.fetch(0, "/tmp/gh-aw/agent")
output_path = File.join(directory, "../agent_output.json")
output = JSON.parse(File.read(output_path))
items = output.fetch("items")
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
item["body"] = DependencyFactory::ReportText.publishable(item.fetch("body"))
File.write(body_path, item.fetch("body"))
checkout_status, git_status = Open3.capture2e("git", "status", "--porcelain", "--untracked-files=all")
abort "Commit checkout changes before publishing" unless git_status.success? && checkout_status.empty?
report_checker = File.join(__dir__, "check_dependency_report.rb")
abort "Dependency report failed validation" unless system("bundle", "exec", "ruby", report_checker, File.join(directory, "dependency-candidates.json"), body_path, context.fetch("base"), File.join(directory, "release-notes.json"))
update_checker = File.join(__dir__, "check_dependency_update.rb")
abort "Dependency update failed mechanical validation" unless system("bundle", "exec", "ruby", update_checker, context.fetch("base"))
items.select { |entry| %w[create_pull_request push_to_pull_request_branch].include?(entry["type"]) }.each do |entry|
  errors = DependencyFactory::Transport.errors(entry, directory: directory)
  abort errors.join("\n") unless errors.empty?
end
# Publish the same repaired URLs that passed validation, without unescaping prose mentions.
File.write(output_path, JSON.generate(output))
