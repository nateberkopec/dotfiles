module DependencyFactory
  class RubricChecks
    PATCH_PHRASE = "Patch release; staying current."
    BOILERPLATE = /\b(general|various|assorted|miscellaneous|misc|maintenance|routine)\b.{0,20}\b(fix|improvement|release|update)|bug[ -]?fix(es)?\b.{0,12}\b(release|only)|stay(s|ing)?\b.{0,12}\b(current|up[ -]to[ -]date)|keeps?\b.{0,40}\b(current|latest|up[ -]to[ -]date)|updates?\b.{0,40}\bto the latest/i
    ADVISORY = %r{/advisories/|GHSA-|CVE-\d|osv\.dev|/security/}i
    QUOTE = /[“"][^”"]{20,}[”"]/
    LABELS = ["Security:", "Benefit:", "Irrelevant changes:", "Cost and risk:", "Recommendation:"].freeze

    def initialize(report:)
      @report = report
    end

    def errors
      [tables, links, security_flags, rubric, assessments].flatten
    end

    private

    def rows(title)
      @report.rows(title)
    end

    def tables
      Report::TABLES.filter_map do |title, columns|
        "#{title} table must have the columns #{columns.join(" | ")}" unless @report.header(title) == columns
      end
    end

    def links
      {"Updates" => "Why", "Skipped candidates" => "Candidate", "Snoozed candidates" => "Candidate"}.flat_map do |title, column|
        rows(title).reject { |row| Report.link_text(row[column].to_s) }.map { |row| "#{Report.tool(row["Tool"])}: #{column} must link to a primary source" }
      end
    end

    def security_flags
      Report::TABLES.keys.flat_map do |title|
        rows(title).reject { |row| %w[true false].include?(row["Security"]) }.map { |row| "#{Report.tool(row["Tool"])}: Security must be true or false" }
      end
    end

    def rubric
      rows("Updates").flat_map do |row|
        name = Report.tool(row["Tool"])
        [why_error(name, row), ("#{name}: Security true needs an advisory link or a quoted excerpt in its assessment" if row["Security"] == "true" && !advisory?(name, row))].compact
      end
    end

    def why_error(name, row)
      why = Report.link_text(row["Why"].to_s).to_s
      if why == PATCH_PHRASE
        "#{name}: '#{PATCH_PHRASE}' is only allowed for patch-level bumps" unless name == Candidates::BATCH || Versions.patch_bump?(row["Old"], row["New"])
      elsif why.match?(BOILERPLATE)
        "#{name}: Why must name a concrete benefit, not '#{why}'"
      end
    end

    def advisory?(name, row)
      bullet = @report.assessment(name).to_s
      Report.urls(row["Why"].to_s + bullet).any? { |url| url.match?(ADVISORY) } || bullet.match?(QUOTE)
    end

    def assessments
      (rows("Updates") + rows("Skipped candidates")).map { |row| Report.tool(row["Tool"]) }.uniq.flat_map do |name|
        bullet = @report.assessment(name)
        next ["#{name}: Dependency assessments needs a bullet that starts with `#{name} <version>`"] unless bullet
        LABELS.reject { |label| bullet.include?(label) }.map { |label| "#{name}: assessment is missing #{label}" }
      end
    end
  end
end
