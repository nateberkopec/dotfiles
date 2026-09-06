#!/usr/bin/env ruby
require "json"
require "open3"

# Resolve the single writable batch before the agent starts; never trust agent-selected targets.
def capture(*args)
  text, status = Open3.capture2(*args)
  abort "Failed: #{args.join(" ")}" unless status.success?
  text.strip
end

def api(path)
  JSON.parse(capture("gh", "api", "repos/#{ENV.fetch("GITHUB_REPOSITORY")}/#{path}"))
end

directory = "/tmp/gh-aw/agent"
benchmark = ENV["BENCHMARK"] == "true"
branch = benchmark ? "dependency-benchmark-642" : "main"
base = capture("git", "rev-parse", "origin/#{branch}")
abort "Benchmark base moved" if benchmark && base != "f5a1dca77a863ed9d5f6c24121b1d9b94026acd2"
number = ENV["PR_NUMBER"].to_s
issue = ENV["ISSUE_NUMBER"].to_s
number = issue if number.empty? && !issue.empty? && api("issues/#{issue}")["pull_request"]
open = api("pulls?state=open&base=#{branch}&per_page=100").select { |pr| pr["labels"].any? { |label| label["name"] == "dependency-update" } }
abort "Multiple active dependency batches require human resolution" if open.size > 1
number = open.first["number"].to_s if number.empty? && !open.empty?
context = {"base" => base, "base_branch" => branch, "issue" => issue, "benchmark" => benchmark, "human_request" => ENV["HUMAN_REQUEST"] == "true"}
unless number.empty?
  pr = api("pulls/#{number}")
  abort "Not an owned dependency batch" unless pr["state"] == "open" && pr["base"]["ref"] == branch && pr["head"]["repo"]["full_name"] == ENV.fetch("GITHUB_REPOSITORY") && pr["labels"].any? { |label| label["name"] == "dependency-update" }
  head = pr["head"]["sha"]
  abort "Stale CI event" unless ENV["EVENT_HEAD"].to_s.empty? || ENV["EVENT_HEAD"] == head
  base = capture("git", "merge-base", base, head)
  context.merge!("number" => pr["number"], "head" => head, "base" => base)
  File.write("#{directory}/pr.json", JSON.pretty_generate(pr))
end
File.write("#{directory}/pr-context.json", JSON.pretty_generate(context))
File.open(ENV.fetch("GITHUB_OUTPUT"), "a") { |file| file.puts "pr_number=#{number}\nbase_branch=#{branch}" }
