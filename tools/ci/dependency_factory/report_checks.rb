require "time"

module DependencyFactory
  class ReportChecks
    def initialize(candidates:, report:, changes:, snoozes:, notes:, original_snoozes: snoozes)
      @report, @changes, @snoozes = report, changes, snoozes
      @evidence = ReportEvidence.new(notes.fetch("packages"))
      @original_snoozes = original_snoozes
      @pins = candidates.fetch("candidates").flat_map { |candidate| candidate["members"] || [candidate] }
      @age = candidates.fetch("minimum_release_age_days") * 86_400
      @cutoff = Time.iso8601(candidates.fetch("generated_at")) - @age
    end

    def errors
      format = @report.errors
      return format unless format.empty?
      [memory, coverage, decisions, changes].flatten
    end

    private

    def memory
      @original_snoozes.filter_map do |name, decision|
        "#{name}: existing snooze requires a human edit" unless @snoozes[name] == decision
      end
    end

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
        pin = @pins.find { |entry| entry["name"] == name }
        selected = @changes[name]&.last == version
        [("#{name} #{version}: decision disagrees with diff" unless (row["action"] == "update") == selected),
          *@evidence.errors(row, pin),
          *wake_errors(row, pin)].compact
      end
    end

    def wake_errors(row, pin)
      date = pin && publication_date(pin, row["version"])
      return [] unless date && Time.iso8601(date) > @cutoff
      wake = (Time.iso8601(date) + @age).utc.iso8601
      row["reason"].include?(wake) ? [] : ["#{row["name"]} #{row["version"]}: age-gated decision must include wake time #{wake}"]
    end

    def publication_date(pin, version)
      pin.fetch("published")[version] || pin.fetch("releases", []).find { |release| release["version"] == version }&.fetch("created_at", nil)
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
      date = publication_date(pin, version)
      [("#{name}: #{version} outside eligible range" unless Versions.newer?(version, pin["current"]) && !Versions.newer?(version, pin["eligible"])),
        ("#{name}: #{version} has no eligible publication date" unless date && Time.iso8601(date) <= @cutoff),
        ("#{name}: snoozed until #{@snoozes[name]["wake_at"]}" if snoozed?(pin, version))].compact
    end

    def snoozed?(pin, version)
      snooze = @snoozes[pin["name"]]
      snooze && Versions.newer?(snooze["wake_at"], version) && !@report.decisions.any? do |row|
        row["name"] == pin["name"] && row["security"] == true && row["source"].to_s.match?(%r{/advisories/|/security/|CVE-\d|osv\.dev}i)
      end
    end
  end
end
