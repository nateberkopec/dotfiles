#!/usr/bin/env ruby

DIRECTION_ENV = "I_HAVE_EXPLICIT_HUMAN_DIRECTION_TO_MODIFY_DOCS"

staged_files = `git diff --cached --name-only --no-renames -z`.split("\0")
blocked_files = staged_files.select do |path|
  path == "README.md" || path.start_with?("docs/")
end

exit 0 if blocked_files.empty? || ENV[DIRECTION_ENV] == "1"

warn "Protected documentation changes are staged:"
blocked_files.each { |path| warn "  #{path}" }
warn <<~MESSAGE

  Do not change these files unless the human explicitly directed you to.
  See AGENTS.md: "Protected documentation".

  If the human did not explicitly request these documentation changes:
  - Remove your unsolicited changes, preserving any pre-existing human work.
  - Do not ask for permission to include them.
  - Continue with the requested task without changing these files.

  If the human explicitly directed these changes, retry this commit with:
  #{DIRECTION_ENV}=1

  Do not set this variable merely to make the check pass, persist it in
  your environment, or bypass the hook.
MESSAGE

exit 1
