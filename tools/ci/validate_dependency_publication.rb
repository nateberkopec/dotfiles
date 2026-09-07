#!/usr/bin/env ruby
require_relative "dependency_factory"
require "tmpdir"
require "fileutils"

# Called only in the fresh validation job. The agent's checkout is never opened.
def git(*arguments)
  DependencyFactory::Sources.capture({}, "git", *arguments)
end

def copy_input(source, destination)
  abort "Expected regular input: #{source}" unless File.lstat(source).file? && !File.symlink?(File.dirname(source))
  FileUtils.cp(source, destination)
end

def queued_bundle(item, directory)
  repo = ENV.fetch("GITHUB_REPOSITORY")
  abort "Cross-repository publication is forbidden" unless [nil, repo].include?(item["repo"])
  branch = item.fetch("branch")
  git("check-ref-format", "refs/heads/#{branch}")
  DependencyFactory::Transport.queued_bundle(item, directory: directory, repo: repo) || abort("Missing queued bundle for #{branch}")
end

def check_commit_scope(commit)
  git("diff-tree", "--root", "--no-commit-id", "--no-renames", "-r", "-m", "--raw", "-z", commit).split("\0").each_slice(2) do |header, path|
    modes = header.split.first(2)
    abort "Forbidden dependency path or mode: #{path}" unless (DependencyFactory::Manifests::PATHS + %w[config/dependency-updater.yml files/home/.config/mise/mise.lock]).include?(path) && modes == [":100644", "100644"]
  end
end

def import_bundle(item, directory, target, base)
  source = queued_bundle(item, directory)
  bundle = File.join(File.dirname(target), File.basename(source))
  copy_input(source, bundle)
  heads = git("bundle", "list-heads", bundle).lines.map(&:split)
  ref = "refs/heads/#{item.fetch("branch")}"
  abort "Unexpected bundle refs" unless heads.size == 1 && heads.first.last == ref
  git("bundle", "verify", bundle)
  git("bundle", "unbundle", bundle) # Parse the pack even when every object already exists locally.
  git("-c", "fetch.fsckObjects=true", "fetch", "--no-tags", bundle, "#{ref}:refs/heads/validated-candidate")
  git("fsck", "--full", "--strict")
  git("merge-base", "--is-ancestor", base, "validated-candidate")
  git("rev-list", "#{base}..validated-candidate").lines.each { |commit| check_commit_scope(commit.strip) }
  git("checkout", "--quiet", "--detach", "validated-candidate")
  source
end

directory, evidence = ARGV.map { |path| File.expand_path(path) }
source = Dir.pwd
ENV["BUNDLE_GEMFILE"] = File.join(source, "Gemfile")
ENV["GIT_CONFIG_GLOBAL"] = ENV["GIT_CONFIG_SYSTEM"] = File::NULL
ENV["GIT_NO_REPLACE_OBJECTS"] = "1"
context_path = File.join(evidence, "pr-context.json")
context = JSON.parse(File.read(context_path, encoding: "UTF-8"))
base = context["head"] || context.fetch("base")
abort "Expected commit SHAs" unless [base, context.fetch("base")].all? { |sha| sha.match?(/\A[0-9a-f]{40}\z/) }
checker = File.join(source, "tools/ci/check_dependency_output.rb")
abort "Invalid output" unless system("bundle", "exec", "ruby", checker, directory, context_path)
items = JSON.parse(File.read(File.join(directory, "../agent_output.json"), encoding: "UTF-8")).fetch("items")
item = items.find { |entry| %w[create_pull_request push_to_pull_request_branch].include?(entry["type"]) }
Dir.mktmpdir("dependency-validation-") do |root|
  target = File.join(root, "agent")
  git("clone", "--quiet", "--no-hardlinks", "--no-checkout", source, File.join(root, "checkout"))
  Dir.chdir(File.join(root, "checkout")) do
    git("config", "core.hooksPath", File::NULL)
    git("checkout", "--quiet", "--detach", base)
    if item
      import_bundle(item, directory, target, base)
      %w[check_dependency_update check_dependency_eligibility].each do |name|
        arguments = name.end_with?("eligibility") ? [context_path, File.join(evidence, "dependency-candidates.json")] : [context.fetch("base")]
        abort "Invalid dependency change" unless system("bundle", "exec", "ruby", File.join(source, "tools/ci/#{name}.rb"), *arguments)
      end
    end
  end
end
if context["number"]
  pr = JSON.parse(DependencyFactory::Sources.capture({}, "gh", "api", "repos/#{ENV.fetch("GITHUB_REPOSITORY")}/pulls/#{context["number"]}"))
  abort "Stale PR" unless pr.dig("head", "sha") == base && pr.dig("base", "ref") == "dependency-benchmark-642" && pr["state"] == "open" && pr.dig("base", "sha") == context["base_head"]
end
unless context["number"]
  remote = JSON.parse(DependencyFactory::Sources.capture({}, "gh", "api", "repos/#{ENV.fetch("GITHUB_REPOSITORY")}/git/ref/heads/dependency-benchmark-642"))
  abort "Main advanced during this run" unless remote.dig("object", "sha") == base
end
