#!/usr/bin/env ruby

require "English"

class TestRuntimeCheck
  DEFAULT_THRESHOLD_SECONDS = 10.0
  COMMAND = ["mise", "run", "test"].freeze

  def run
    started_at = monotonic_time
    success = system(*COMMAND)
    elapsed = monotonic_time - started_at

    warn_if_slow(elapsed) if success
    exit($CHILD_STATUS.exitstatus || 1) unless success
  end

  private

  def warn_if_slow(elapsed)
    return if elapsed <= threshold_seconds

    warn format("WARNING: mise run test took %.2fs, above the %.2fs pre-commit target.", elapsed, threshold_seconds)
    warn "Acceptable remediations: run tests only for changed files; add/use a test:fast task"
    warn "that still covers 100% of unit-level app coverage; or keep this warning if neither"
    warn "approach can get the test task under 10 seconds."
  end

  def threshold_seconds
    @threshold_seconds ||= begin
      configured_threshold = ENV.fetch("TEST_RUNTIME_THRESHOLD_SECONDS", DEFAULT_THRESHOLD_SECONDS).to_f
      configured_threshold.positive? ? configured_threshold : DEFAULT_THRESHOLD_SECONDS
    end
  end

  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end

TestRuntimeCheck.new.run
