#!/usr/bin/env ruby
require_relative "dependency_factory"
require "json"

# Runs only from the trusted publisher checkout; reports are prose, not executable policy.
directory, context_path = ARGV
context = JSON.parse(File.read(context_path))
items = JSON.parse(File.read(File.join(directory, "../agent_output.json"))).fetch("items")
allowed = {
  "create_pull_request" => %w[type title body branch base repo draft labels],
  "push_to_pull_request_branch" => %w[type branch pull_request_number message repo],
  "update_pull_request" => %w[type pull_request_number body operation repo],
  "add_comment" => %w[type item_number body repo], "noop" => %w[type message],
  "missing_data" => %w[type reason], "missing_tool" => %w[type reason], "report_incomplete" => %w[type reason]
}
abort "Missing explicit outcome" if items.empty?
items.each do |item|
  next if %w[missing_data missing_tool report_incomplete noop].include?(item["type"])
  abort "Unexpected repository" if item["repo"] && item["repo"] != ENV.fetch("GITHUB_REPOSITORY")
  abort "Unexpected base" if item["base"] && item["base"] != "main"
  abort "Unexpected labels" if item["labels"] && item["labels"] != ["dependency-update"]
  abort "Expected draft proposal" if item.key?("draft") && item["draft"] != true
  abort "Unexpected output fields" unless allowed.key?(item["type"]) && (item.keys - allowed.fetch(item["type"]) - %w[secrecy integrity]).empty?
  type = item["type"]
  abort "Unexpected create" if type == "create_pull_request" && context["number"]
  if %w[update_pull_request push_to_pull_request_branch add_comment].include?(type)
    target = item["pull_request_number"] || item["item_number"]
    abort "Unexpected target" unless context["number"] && target.to_s == context["number"].to_s
  end
  abort "Unexpected push branch" if type == "push_to_pull_request_branch" && item["branch"] != context["branch"]
end
abort "Multiple publications" if items.count { |item| %w[create_pull_request push_to_pull_request_branch].include?(item["type"]) } > 1
