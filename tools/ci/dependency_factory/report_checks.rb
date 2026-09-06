require "time"

module DependencyFactory
  class ReportChecks
    def initialize(candidates:, report:, changes:, snoozes:, notes:)
      @report, @changes, @snoozes = report, changes, snoozes
      @notes = notes.fetch("packages")
      @pins = candidates.fetch("candidates").flat_map { |candidate| candidate["members"] || [candidate] }
      @cutoff = Time.iso8601(candidates.fetch("generated_at")) - candidates.fetch("minimum_release_age_days") * 86_400
    end

    def errors
      format = @report.errors
      return format unless format.empty?
      [coverage, decisions, changes].flatten
    end

    private

    def coverage
      expected = @pins.flat_map do |pin|
        [pin["eligible"], pin["latest"], @changes[pin["name"]]&.last].compact.uniq.filter_map do |version|
          [pin["name"], version] if Versions.newer?(version, pin["current"])
        end
      end
      actual = @report.decisions.map { |row| row.values_at("name", "version") }
      [*(expected - actual).map { |name, version| "#{name} #{version}: missing decision" },
        *(actual - expected).map { |name, version| "#{name} #{version}: not a candidate" }]
    end

    def decisions
      @report.decisions.flat_map do |row|
        name, version = row.values_at("name", "version")
        note = (@notes[name] || []).find { |entry| entry["version"] == version && entry["url"] == row["source"] }
        pin = @pins.find { |entry| entry["name"] == name }
        selected = @changes[name]&.last == version
        [("#{name} #{version}: decision disagrees with diff" unless (row["action"] == "update") == selected),
          ("#{name} #{version}: source is not collected evidence" unless collected?(row, note, pin)),
          ("#{name} #{version}: security requires an exact collected quote" if row["security"] && !quoted?(row, note))].compact
      end
    end

    def collected?(row, note, pin)
      note || pin&.fetch("source", nil) == row["source"]
    end

    def quoted?(row, note)
      quote = row["quote"].to_s
      note && !note["error"] && quote.size >= 20 && note["text"].to_s.include?(quote)
    end

    def changes
      @changes.flat_map do |name, (old, version)|
        next [] if name == Candidates::BATCH
        pin = @pins.find { |entry| entry["name"] == name }
        next ["#{name}: changed but not a candidate; refresh discovery"] unless pin
        [("#{name}: old pin disagrees with baseline" unless pin["current"] == old), *version_errors(pin, version)].compact
      end
    end

    def version_errors(pin, version)
      name = pin["name"]
      date = pin.fetch("published")[version] || pin.fetch("releases", []).find { |release| release["version"] == version }&.fetch("created_at", nil)
      [("#{name}: #{version} outside eligible range" unless Versions.newer?(version, pin["current"]) && !Versions.newer?(version, pin["eligible"])),
        ("#{name}: #{version} has no eligible publication date" unless date && Time.iso8601(date) <= @cutoff),
        ("#{name}: snoozed until #{@snoozes[name]["wake_at"]}" if snoozed?(pin))].compact
    end

    def snoozed?(pin)
      snooze = @snoozes[pin["name"]]
      snooze && Versions.newer?(snooze["wake_at"], pin["eligible"]) && !@report.decisions.any? do |row|
        row["name"] == pin["name"] && row["security"] && row["source"].match?(%r{/advisories/|/security/|CVE-\d|osv\.dev}i)
      end
    end
  end
end
