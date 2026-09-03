#!/usr/bin/env ruby
require_relative "dependency_factory"

committed_path, native_path, *platforms = ARGV
abort "Usage: check_lock_provenance.rb COMMITTED_LOCK NATIVE_LOCK PLATFORM..." if platforms.empty?
committed = DependencyFactory::LockProvenance.new(File.read(committed_path))
native = DependencyFactory::LockProvenance.new(File.read(native_path))
platforms.flat_map { |platform| committed.verified_by(native, platform) }.each { |line| puts "+ #{line}" }
errors = platforms.flat_map { |platform| committed.unverified_by(native, platform) }
errors.each { |error| warn "✗ #{error}" }
abort "#{errors.size} lock provenance problem(s)" unless errors.empty?
puts "Native lock generation reproduced every provenance_verified entry for #{platforms.join(", ")}"
