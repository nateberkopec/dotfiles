#!/usr/bin/env ruby
require_relative "dependency_factory"
require "tmpdir"
require "fileutils"
require "digest"

# Called only in the fresh validation job. The agent's checkout is never opened.
def git(*arguments)
  DependencyFactory::Sources.capture({}, "git", *arguments)
end

def copy_input(source, destination)
  abort "Expected regular input: #{source}" unless File.lstat(source).file? && !File.symlink?(File.dirname(source))
  FileUtils.cp(source, destination)
end

def copy_evidence(directory, evidence, target)
  %w[pr-context dependency-candidates release-notes].map do |name|
    source = File.join(directory, "#{name}.json")
    copy_input(source, File.join(target, "#{name}.json"))
    abort "Changed trusted evidence: #{name}" unless File.binread(source) == File.binread(File.join(evidence, "#{name}.json"))
    source
  end
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
    abort "Forbidden dependency path or mode: #{path}" unless DependencyFactory::DEPENDENCY_PATHS.include?(path) && modes == [":100644", "100644"]
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

directory, evidence, manifest = ARGV.map { |path| File.expand_path(path) }
source = Dir.pwd
ENV["BUNDLE_GEMFILE"] = File.join(source, "Gemfile")
ENV["GIT_CONFIG_GLOBAL"] = ENV["GIT_CONFIG_SYSTEM"] = File::NULL
ENV["GIT_NO_REPLACE_OBJECTS"] = "1"
Dir.mktmpdir("dependency-validation-") do |root|
  target = File.join(root, "agent")
  Dir.mkdir(target)
  inputs = copy_evidence(directory, evidence, target)
  payload = File.join(directory, "../agent_output.json")
  copy_input(payload, File.join(root, "agent_output.json"))
  inputs << payload
  context = JSON.parse(File.read(File.join(target, "pr-context.json")))
  base = context["head"] || context.fetch("base")
  abort "Expected commit SHAs" unless [base, context.fetch("base")].all? { |sha| sha.match?(/\A[0-9a-f]{40}\z/) }
  items = JSON.parse(File.read(payload)).fetch("items").select { |item| %w[create_pull_request push_to_pull_request_branch].include?(item["type"]) }
  abort "Expected at most one queued bundle" if items.size > 1
  git("clone", "--quiet", "--no-hardlinks", "--no-checkout", source, File.join(root, "checkout"))
  Dir.chdir(File.join(root, "checkout")) do
    git("config", "core.hooksPath", File::NULL)
    git("checkout", "--quiet", "--detach", base)
    inputs << import_bundle(items.first, directory, target, base) unless items.empty?
    checker = File.join(source, "tools/ci/check_dependency_output.rb")
    abort "Publication validation failed" unless system("bundle", "exec", "ruby", checker, target)
  end
  File.write(manifest, inputs.map { |path| "#{Digest::SHA256.file(path).hexdigest}  #{File.expand_path(path)}\n" }.join)
end
