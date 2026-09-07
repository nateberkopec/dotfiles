module DependencyFactory
  class Report
    TABLES = {"Updates" => %w[Tool Old New], "Skipped candidates" => %w[Tool Candidate Reason]}.freeze
    SECTIONS = ["Release notes", *TABLES.keys, "Attention"].freeze
    LINK = %r{\[([^\]]+)\]\((https://[^)\s`]+)\)}

    def self.urls(text)
      text.to_s.scan(LINK).map(&:last)
    end

    def self.advisory?(text)
      urls(text).any? { |url| url.match?(%r{/advisories/|/security/|CVE-\d|osv\.dev}i) }
    end

    def self.value(text)
      (text.to_s[LINK, 1] || text.to_s).delete("`").strip
    end

    def initialize(body)
      @body = body
    end

    def section(title)
      @body[/^## #{Regexp.escape(title)}\n(.*?)(?=^## |\z)/m, 1].to_s
    end

    def bullets(title)
      section(title).lines.grep(/^- /)
    end

    def rows(title)
      lines = table(title)
      lines.drop(2).map { |line| lines.first.zip(line).to_h }
    end

    def security
      bullets("Attention").filter_map do |line|
        match = line.match(/\A- Security: `(.+) ([^` ]+)`:/)
        [self.class.value(match[1]), match[2], line] if match
      end
    end

    def errors
      [*heading_errors,
        ("Release notes needs up to five linked highlights, or a short no-highlights explanation" if section("Release notes").strip.empty? || bullets("Release notes").size > 5),
        ("Finish with a short Validation: line" unless @body.match?(/^Validation: \S/)),
        ("Security bullets must identify `tool version`" unless bullets("Attention").grep(/^- Security:/).size == security.size),
        *table_errors].compact
    end

    private

    def heading_errors
      headings = @body.scan(/^## (.+)$/).flatten
      [*(headings - SECTIONS).map { |title| "Unexpected section: #{title}" },
        ("Start with Release notes, Updates, and Skipped candidates in that order" unless headings.first(3) == SECTIONS.first(3)),
        ("Do not repeat sections" unless headings.uniq == headings)].compact
    end

    def table(title)
      section(title).lines.grep(/^\|/).map { |line| cells(line) }
    end

    def table_errors
      TABLES.flat_map do |title, columns|
        lines = table(title)
        next ["#{title} table must have columns #{columns.join(" | ")}"] unless lines.first == columns
        next ["#{title}: missing table separator"] unless lines[1]&.all? { |cell| cell.match?(/\A:?-+:?\z/) }
        lines.drop(2).flat_map { |line| row_errors(title, line) }
      end
    end

    def row_errors(title, line)
      version_index = (title == "Updates") ? 2 : 1
      [("#{title}: every cell must be filled" unless line.size == TABLES[title].size && line.none?(&:empty?)),
        ("#{line.first}: link the version to its source" if self.class.urls(line[version_index]).empty?)].compact
    end

    def cells(line)
      line.strip.sub(/\A\|/, "").sub(/\|\z/, "").split("|", -1).map(&:strip)
    end
  end
end
