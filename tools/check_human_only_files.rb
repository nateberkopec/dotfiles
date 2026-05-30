#!/usr/bin/env ruby

PROTECTED_PATHS = ["README.md", "docs/**"].freeze
BYPASS_ENV = "DOTF_ALLOW_HUMAN_ONLY_CHANGES"

staged_files = `git diff --cached --name-only --diff-filter=ACMR -z`.split("\0")
blocked_files = staged_files.select do |path|
  path == "README.md" || path.start_with?("docs/")
end

exit 0 if blocked_files.empty? || ENV[BYPASS_ENV] == "1"

warn "Human-only files are staged:"
blocked_files.each { |path| warn "  - #{path}" }
warn ""
warn "These paths are intended for human edits only: #{PROTECTED_PATHS.join(", ")}"
warn "This is an advisory local guard; bypass with #{BYPASS_ENV}=1 if needed."

exit 1
