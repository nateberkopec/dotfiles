# frozen_string_literal: true

require_relative "agent_skill_lint"

skills_root = ARGV.first || File.expand_path("../files/home/.claude/skills", __dir__)
errors = AgentSkillLint.new(skills_root).errors
warn errors.join("\n") unless errors.empty?
exit 1 unless errors.empty?
