# frozen_string_literal: true

require "find"
require "yaml"

class AgentSkillLint
  SKILLS_ROOT = File.expand_path("../files/home/.claude/skills", __dir__)

  def run
    errors = lowercase_skill_paths + invalid_skill_paths
    return if errors.empty?

    warn errors.join("\n")
    exit 1
  end

  private

  def lowercase_skill_paths
    paths_under_skills.select { |path| File.basename(path) == "skill.md" }.map do |path|
      "Use SKILL.md, not skill.md: #{relative_path(path)}"
    end
  end

  def invalid_skill_paths
    skill_paths.filter_map do |path|
      validate_skill(path)
    end
  end

  def skill_paths
    paths_under_skills.select { |path| File.basename(path) == "SKILL.md" }.sort
  end

  def validate_skill(path)
    frontmatter = load_frontmatter(path)
    return "Missing YAML frontmatter: #{relative_path(path)}" unless frontmatter

    name_error(path, frontmatter) || description_error(path, frontmatter)
  rescue Psych::SyntaxError => e
    "Invalid YAML frontmatter in #{relative_path(path)}: #{e.message}"
  end

  def name_error(path, frontmatter)
    skill_dir = File.basename(File.dirname(path))
    name = frontmatter["name"].to_s.strip
    return if name == skill_dir

    "Skill name must match directory #{skill_dir.inspect}: #{relative_path(path)}"
  end

  def description_error(path, frontmatter)
    return unless frontmatter["description"].to_s.strip.empty?

    "Skill description is required: #{relative_path(path)}"
  end

  def load_frontmatter(path)
    content = File.read(path)
    match = content.match(/\A---\n(.*?)\n---\n/m)
    return unless match

    YAML.safe_load(match[1]) || {}
  end

  def paths_under_skills
    Find.find(SKILLS_ROOT).select { |path| File.file?(path) }
  end

  def relative_path(path)
    path.delete_prefix("#{File.expand_path("..", __dir__)}/")
  end
end

AgentSkillLint.new.run
