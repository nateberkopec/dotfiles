# frozen_string_literal: true

require "find"
require "json"
require "yaml"
require_relative "agent_skill_lint/equivalence_checks"
require_relative "agent_skill_lint/eval_checks"
require_relative "agent_skill_lint/reference_checks"

# Implements the mechanically checkable findings from Intercom's skill-review rubric:
# https://github.com/intercom/2x-skills/blob/main/plugins/skill-tools/skills/skill-review/SKILL.md
class AgentSkillLint
  include AgentSkillEquivalenceChecks
  include AgentSkillEvalChecks
  include AgentSkillReferenceChecks

  SEVERITIES = {
    "eval-quality-issues" => "minor",
    "repo-convention-violation" => "minor"
  }.freeze

  def initialize(root)
    @root = root
  end

  def errors
    lowercase_skill_paths + skill_paths.flat_map { |path| skill_errors(path) }
  end

  private

  attr_reader :root

  def skill_errors(path)
    frontmatter = load_frontmatter(path)
    return [finding("repo-convention-violation", "Missing YAML frontmatter", path)] unless frontmatter

    convention_errors(path, frontmatter) + reference_errors(path, frontmatter) + equivalence_errors(path) + eval_errors(path)
  rescue Psych::SyntaxError => e
    [finding("repo-convention-violation", "Invalid YAML frontmatter: #{e.message}", path)]
  end

  def convention_errors(path, frontmatter)
    expected = File.basename(File.dirname(path))
    errors = []
    name = frontmatter["name"].to_s.strip
    unless name == expected
      errors << finding("repo-convention-violation", "Skill name must match directory #{expected.inspect}", path)
    end
    unless name.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/) && name.length.between?(1, 40)
      errors << finding("repo-convention-violation", "Skill name must use 1–40 lowercase letters, digits, and single hyphens", path)
    end
    if frontmatter["description"].to_s.strip.empty?
      errors << finding("repo-convention-violation", "Skill description is required", path)
    end
    errors
  end

  def lowercase_skill_paths
    paths_under_skills.select { |path| File.basename(path) == "skill.md" }.map do |path|
      finding("repo-convention-violation", "Use SKILL.md, not skill.md", path)
    end
  end

  def skill_names
    @skill_names ||= skill_paths.map { |path| File.basename(File.dirname(path)) }
  end

  def skill_paths
    @skill_paths ||= paths_under_skills.select { |path| File.basename(path) == "SKILL.md" }.sort
  end

  def paths_under_skills
    paths = []
    Find.find(root) do |path|
      Find.prune if File.directory?(path) && File.basename(path) == ".system"
      paths << path if File.file?(path)
    end
    paths
  end

  def load_frontmatter(path)
    match = File.read(path).match(/\A---\n(.*?)\n---\n/m)
    YAML.safe_load(match[1]) || {} if match
  end

  def finding(type, message, path)
    severity = SEVERITIES.fetch(type, "major")
    "#{type} (deterministic, #{severity}): #{message}: #{path.delete_prefix("#{root}/")}"
  end
end
