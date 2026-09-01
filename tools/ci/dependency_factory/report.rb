module DependencyFactory
  class Report
    TABLES = {
      "Updates" => %w[Tool Old New Security Why],
      "Skipped candidates" => %w[Tool Candidate Security],
      "Snoozed candidates" => %w[Tool Candidate Security]
    }.freeze
    LINK = %r{\[([^\]]+)\]\((https://[^)\s]+)\)}

    def self.link_text(cell)
      cell[LINK, 1]
    end

    def self.urls(cell)
      cell.scan(LINK).map(&:last)
    end

    def self.tool(cell)
      cell.to_s.delete("`").strip
    end

    def initialize(body)
      @body = body
    end

    def section(title)
      @body[/^## #{Regexp.escape(title)}\n(.*?)(?=^## |\z)/m, 1].to_s
    end

    def header(title)
      line = table_lines(title).first
      line && cells(line)
    end

    def rows(title)
      lines = table_lines(title)
      return [] if lines.size < 3
      keys = cells(lines[0])
      lines.drop(2).map { |line| keys.zip(cells(line)).to_h }
    end

    def assessment(tool)
      section("Dependency assessments").lines.find { |line| line.match?(/\A- `#{Regexp.escape(tool)}[` ]/) }
    end

    private

    def table_lines(title)
      section(title).lines.map(&:strip).select { |line| line.start_with?("|") }
    end

    def cells(line)
      line.sub(/\A\|/, "").sub(/\|\z/, "").split("|").map(&:strip)
    end
  end
end
