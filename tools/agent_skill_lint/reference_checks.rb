# frozen_string_literal: true

module AgentSkillReferenceChecks
  private

  def reference_errors(path, frontmatter)
    body = skill_markdown(path)
    internal_skill_errors(path, body) + allowed_tool_errors(path, body, frontmatter)
  end

  def internal_skill_errors(path, body)
    referenced_skill_names(body).filter_map do |name|
      next if skill_names.include?(name) || system_skill_names.include?(name)

      finding("internal-slash-command-or-skill-reference-doesnt-resolve", "Internal skill /#{name} does not resolve", path)
    end
  end

  def referenced_skill_names(body)
    slash_names = body.scan(/\bRun (?:an? )?`\/([a-z][a-z0-9-]*)`/i).flatten
    invoked_names = body.scan(/Skill\s*\(\s*skill:\s*["']([a-z][a-z0-9-]*)["']/).flatten
    (slash_names + invoked_names).uniq
  end

  def system_skill_names
    @system_skill_names ||= Dir.glob(File.join(root, ".system", "*", "SKILL.md")).map do |path|
      File.basename(File.dirname(path))
    end
  end

  def allowed_tool_errors(path, body, frontmatter)
    return [] unless frontmatter.key?("allowed-tools")

    allowed = Array(frontmatter["allowed-tools"]).flat_map do |value|
      value.to_s.scan(/[A-Za-z_][A-Za-z0-9_*]*(?:\([^)]*\))?/)
    end
    instructed_tools(body).reject { |tool| tool_allowed?(tool, allowed) }.map do |tool|
      finding("instructed-tool-not-in-allowed-tools", "Instructed tool #{tool} is not in allowed-tools", path)
    end
  end

  def instructed_tools(body)
    tools = instruction_clauses(body).flat_map { |clause| tools_in(clause) }
    tools.concat(standalone_calls(body))
    tools.concat(runnable_fence_tools(body))
    tools.uniq
  end

  def instruction_clauses(body)
    body.split(/[.;]\s+|,\s+(?=(?:avoid|call|dispatch|do not|don't|execute|invoke|launch|never|not|run|use)\b)/i).filter_map do |clause|
      next unless clause.match?(/\b(?:call|dispatch|execute|invoke|launch|run|use)\b/i)
      next if clause.match?(/\A\s*(?:avoid|do not|don't|never|not)\b/i)

      clause.split(/\b(?:instead of|rather than|not)\b/i, 2).first
    end
  end

  def tools_in(clause)
    tools = clause.scan(/\b(Agent|Skill|Task|WebFetch|WebSearch)\b/).flatten
    tools.concat(clause.scan(/\b(mcp__[A-Za-z0-9_]+)\b/).flatten)
  end

  def standalone_calls(body)
    body.lines.filter_map do |line|
      line[/\A\s*(?:[-*]\s*)?((?:Agent|Skill|Task|WebFetch|WebSearch|mcp__[A-Za-z0-9_]+))\s*\(/, 1]
    end
  end

  def runnable_fence_tools(body)
    pattern = /^(?![^\n]*(?:avoid|do not|don't|never))[^\n]*\b(?:execute|invoke|run|use)\b[^\n]*\n(?:\s*\n)?```(bash|fish|python|ruby|sh)\b\n(.*?)^```/im
    body.scan(pattern).filter_map do |language, code|
      command = if %w[bash fish sh].include?(language.downcase)
        code.lines.find { |line| line.match?(/^\s*[^#\s]/) }&.strip
      else
        language.downcase
      end
      "Bash(#{command})" if command
    end
  end

  def tool_allowed?(tool, allowed)
    name, command = tool.match(/\A([^()]+)(?:\(([^)]+)\))?\z/).captures
    allowed.any? do |entry|
      scope = entry[/\A#{Regexp.escape(name)}\((.*):\*\)\z/, 1]
      entry == name || entry == "#{name}(*)" || (scope && command&.start_with?(scope)) ||
        (entry.end_with?("*") && !entry.include?("(") && name.start_with?(entry.delete_suffix("*")))
    end
  end

  def skill_markdown(path)
    Dir.glob(File.join(File.dirname(path), "**", "*.md")).sort.map do |file|
      File.read(file).sub(/\A---\n.*?\n---\n/m, "").gsub(/^```(?:md|markdown|text)\b.*?^```/mi, "")
    end.join("\n")
  end
end
