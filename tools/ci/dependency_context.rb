#!/usr/bin/env ruby
require_relative "dependency_factory"
require "json"

repo = ENV.fetch("GITHUB_REPOSITORY")
event = JSON.parse(File.read(ENV.fetch("GITHUB_EVENT_PATH")))
def api(path)
  JSON.parse(DependencyFactory::Sources.capture({}, "gh", "api", path))
end
number = event.dig("issue", "number") || event.dig("workflow_run", "pull_requests", 0, "number")
unless number
  prs = api("repos/#{repo}/pulls?state=open&per_page=100").select { |pr| pr["labels"].any? { |label| label["name"] == "dependency-update" } }
  abort "Multiple active dependency batches" if prs.size > 1
  number = prs.first&.fetch("number")
end
context = {"base" => api("repos/#{repo}/git/ref/heads/main").fetch("object").fetch("sha"), "owner_request" => false}
if number
  pr = api("repos/#{repo}/pulls/#{number}")
  abort "Invalid dependency target" unless pr["state"] == "open" && pr.dig("head", "repo", "full_name") == repo && pr.dig("base", "ref") == "main" && pr["labels"].any? { |label| label["name"] == "dependency-update" }
  head = pr.dig("head", "sha")
  expected = event.dig("workflow_run", "head_sha")
  abort "Stale CI event" if expected && expected != head
  base = api("repos/#{repo}/compare/#{pr.dig("base", "sha")}...#{head}").fetch("merge_base_commit").fetch("sha")
  context.merge!("number" => number, "head" => head, "base_head" => pr.dig("base", "sha"), "branch" => pr.dig("head", "ref"), "base" => base)
end
if event["comment"]
  actor = event.dig("comment", "user", "login")
  permission = api("repos/#{repo}/collaborators/#{actor}/permission").fetch("permission")
  abort "Only an administrator can direct dependency changes" unless permission == "admin"
  context["owner_request"] = event.dig("comment", "body").to_s.match?(/\A\/dependency-update(?:\s|\z)/)
end
File.write(ARGV.fetch(0), JSON.pretty_generate(context))
