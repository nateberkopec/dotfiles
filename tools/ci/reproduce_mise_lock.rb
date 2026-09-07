#!/usr/bin/env ruby
require_relative "dependency_factory"
require "tmpdir"
require "fileutils"

platform, receipts = ARGV
abort "Expected native platform" unless %w[linux-x64 macos-arm64].include?(platform)
source = Dir.pwd
sha = DependencyFactory::Sources.capture({}, "git", "rev-parse", "HEAD").strip
lock = "files/home/.config/mise/mise.lock"
Dir.mktmpdir("native-lock-") do |scratch|
  DependencyFactory::Sources.capture({}, "git", "clone", "--quiet", "--no-hardlinks", source, scratch)
  DependencyFactory::Sources.capture({}, "git", "-C", scratch, "checkout", "--quiet", "--detach", sha)
  generated = File.join(scratch, lock)
  expected = DependencyFactory::Sources.capture({}, "git", "-C", scratch, "show", "#{sha}:#{lock}")
  proposed = TomlRB.parse(expected)
  other = "platforms.#{(platform == "linux-x64") ? "macos-arm64" : "linux-x64"}"
  seed = proposed.slice("lockfile_version").merge("tools" => proposed.fetch("tools").transform_values { |records| records.reject { |record| record.key?(other) && !record.key?("platforms.#{platform}") }.map { |record| record.slice("version", "backend", "options", "specifiers") } })
  File.write(generated, TomlRB.dump(seed))
  command = File.expand_path("lock_native_platform.sh", __dir__)
  abort "Native generation failed" unless system("bash", command, platform, scratch, chdir: scratch)
  data = TomlRB.load_file(generated)
  proposed.fetch("tools").each do |tool, records|
    keys = records.map { |record| record.values_at("version", "options") }
    abort "Ambiguous native records: #{tool}" unless keys.uniq == keys
    native = data.fetch("tools").fetch(tool)
    records.select { |record| record.key?(other) }.each do |record|
      match = native.find { |entry| entry.values_at("version", "options") == record.values_at("version", "options") }
      match ? match[other] = record[other] : native.push(record.slice("version", "backend", "options", "specifiers", other))
    end
    native.sort_by! { |entry| keys.index(entry.values_at("version", "options")) || keys.length }
  end
  File.write(generated, TomlRB.dump(data))
  success = system("bash", command, platform, scratch, chdir: scratch)
  FileUtils.mkdir_p(receipts)
  FileUtils.cp(generated, File.join(receipts, "#{platform}.lock"))
  abort "Native lock reproduction failed: #{platform}" unless success && File.binread(generated) == expected
  File.write(File.join(receipts, "#{platform}.sha"), "#{sha}\n")
end
