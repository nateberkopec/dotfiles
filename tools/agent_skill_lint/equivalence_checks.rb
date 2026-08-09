# frozen_string_literal: true

module AgentSkillEquivalenceChecks
  private

  def equivalence_errors(path)
    markdown_files(path).flat_map do |file|
      content = File.read(file)
      paired_file_errors(file, content) + prose_count_errors(file, content)
    end
  end

  def paired_file_errors(file, content)
    content.lines.filter_map do |line|
      next unless line.match?(/must (?:be |remain |stay )?(?:identical|the same|match)/i)

      references = line.scan(/(?:`|\]\()([^`\s)]+\.[a-z0-9]+(?:#[a-z0-9-]+)?)/i).flatten
      next unless references.length == 2

      sections = references.map { |reference| referenced_content(file, reference) }
      next unless sections.all? && sections.uniq.length > 1

      finding("paired-files-diverge", "Paired files or sections declared identical do not match", file)
    end
  end

  def prose_count_errors(file, content)
    content.lines.filter_map do |line|
      claim = line.match(/\b(\d+)\s+(columns|patterns)\b/i)
      link = line.match(/\[[^\]]+\]\(([^)]+)\)/)
      next unless claim && link

      table = referenced_content(file, link[1])
      actual = table_size(table, claim[2].downcase) if table
      next unless actual && actual != claim[1].to_i

      finding("prose-count-doesnt-match-referenced-table", "Claims #{claim[1]} #{claim[2]}, but the table has #{actual}", file)
    end
  end

  def referenced_content(source, reference)
    relative, anchor = reference.split("#", 2)
    path = File.expand_path(relative, File.dirname(source))
    return unless File.file?(path)

    content = File.read(path)
    anchor ? anchored_section(content, anchor) : content
  end

  def anchored_section(content, anchor)
    lines = content.lines
    start = lines.index { |line| heading_slug(line) == anchor }
    return unless start

    level = heading_level(lines[start])
    finish = lines.each_index.find { |index| index > start && heading_level(lines[index]).between?(1, level) }
    lines[start...(finish || lines.length)].join
  end

  def heading_slug(line)
    return unless heading_level(line).positive?

    line.sub(/^#+\s+/, "").strip.downcase.gsub(/[^[:alnum:]\s-]/, "").gsub(/\s+/, "-").delete_suffix("-")
  end

  def heading_level(line)
    line[/\A#+(?=\s)/]&.length.to_i
  end

  def table_size(content, kind)
    lines = content.lines
    separator = lines.index { |line| line.match?(/^\s*\|?(?:\s*:?-+:?\s*\|)+/) }
    return unless separator&.positive?
    return table_cells(lines[separator - 1]) if kind == "columns"

    lines[(separator + 1)..].take_while { |line| line.include?("|") && !line.strip.empty? }.length
  end

  def table_cells(line)
    line.strip.delete_prefix("|").delete_suffix("|").split("|").length
  end

  def markdown_files(path)
    Dir.glob(File.join(File.dirname(path), "**", "*.md")).sort
  end
end
