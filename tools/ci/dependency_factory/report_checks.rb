require "time"

module DependencyFactory
  class ReportChecks
    def initialize(candidates:, report:, changes:, snoozes:, notes:)
      @data, @report, @changes, @snoozes = candidates, report, changes, snoozes
      @notes = notes.fetch("packages")
      @candidates = candidates.fetch("candidates")
      @pins = @candidates.flat_map { |candidate| candidate["members"] || [candidate] }
      @by_name = (@candidates + @pins).to_h { |candidate| [candidate["name"], candidate] }
      @cutoff = Time.iso8601(candidates.fetch("generated_at")) - candidates.fetch("minimum_release_age_days") * 86_400
    end

    def errors
      [@report.errors, updates, changes, skipped, highlights, security].flatten
    end

    private

    def updates
      @report.rows("Updates").flat_map do |row|
        name, version = Report.value(row["Tool"]), Report.value(row["New"])
        candidate = @by_name[name]
        next ["#{name}: not an update candidate"] unless @candidates.include?(candidate)
        target = (name == Candidates::BATCH) ? "regenerated" : @changes[name]&.last
        [("#{name}: Old must be #{candidate["current"]}" unless row["Old"] == candidate["current"]),
          ("#{name}: New must match the diff" unless @changes[name] && version == target)].compact
      end
    end

    def changes
      reported = @report.rows("Updates").map { |row| Report.value(row["Tool"]) }
      @changes.flat_map do |name, (old, version)|
        member = @pins.any? { |pin| pin["kind"] == "gem" && pin["name"] == name } || old.nil?
        accounted = reported.include?(name) || (member && reported.include?(Candidates::BATCH))
        next ["#{name}: changed without an Updates row"] unless accounted
        next [] if name == Candidates::BATCH || old.nil?
        pin = @by_name[name]
        pin ? version_errors(pin, version) : ["#{name}: changed but not a candidate"]
      end
    end

    def version_errors(pin, version)
      name, date = pin["name"], publication(pin, version)
      [("#{name}: #{version} must be newer than #{pin["current"]} and no newer than #{pin["eligible"]}" unless Versions.newer?(version, pin["current"]) && !Versions.newer?(version, pin["eligible"])),
        ("#{name}: #{version} has no eligible publication date" unless date && Time.iso8601(date) <= @cutoff),
        ("#{name}: snoozed until #{@snoozes[name]["wake_at"]}" if snoozed?(pin))].compact
    end

    def skipped
      actual = @report.rows("Skipped candidates").map { |row| [Report.value(row["Tool"]), Report.value(row["Candidate"])] }
      expected = @pins.flat_map do |pin|
        [pin["eligible"], pin["latest"]].uniq.filter_map do |version|
          [pin["name"], version] if Versions.newer?(version, pin["current"]) && @changes[pin["name"]]&.last != version
        end
      end
      [*(expected - actual).map { |name, version| "#{name} #{version}: missing from Skipped candidates" },
        *(actual - expected).map { |name, version| "#{name} #{version}: not a skipped candidate" },
        *@report.rows("Skipped candidates").flat_map { |row| reason_errors(row) }]
    end

    def reason_errors(row)
      name, version = Report.value(row["Tool"]), Report.value(row["Candidate"])
      pin = @by_name[name]
      return [] unless pin
      date = publication(pin, version)
      gate = (Time.iso8601(date) + @data["minimum_release_age_days"] * 86_400).utc.iso8601(9).sub(/\.?0+Z\z/, "Z") if date && Time.iso8601(date) > @cutoff
      [*(gate ? [gate] : []), *(snoozed?(pin) ? [@snoozes[name]["wake_at"]] : [])].filter_map do |boundary|
        "#{name} #{version}: Reason must include #{boundary}" unless row["Reason"].to_s.include?(boundary)
      end
    end

    def publication(pin, version)
      pin.fetch("published")[version] || pin.fetch("releases", []).find { |release| release["version"] == version }&.fetch("created_at", nil)
    end

    def snoozed?(pin)
      snooze = @snoozes[pin["name"]]
      snooze && Versions.newer?(snooze["wake_at"], pin["eligible"]) && !@report.security.any? { |name, _, line| name == pin["name"] && Report.advisory?(line) }
    end

    def highlights
      urls = @changes.flat_map do |name, (old, version)|
        (@notes[name] || []).filter_map { |note| note["url"] if old && !note["error"] && Versions.newer?(note["version"], old) && !Versions.newer?(note["version"], version) }
      end
      @report.bullets("Release notes").filter_map do |line|
        "Release notes: each highlight must link only to notes in an upgraded version range" if Report.urls(line).empty? || (Report.urls(line) - urls).any?
      end
    end

    def security_evidence?(name, version, line)
      note = (@notes[name] || []).find { |entry| entry["version"] == version }
      pin = @by_name[name]
      pin && note && Versions.newer?(version, pin["current"]) && !Versions.newer?(version, pin["latest"]) && (Report.advisory?(line) || quoted?(note, line))
    end

    def quoted?(note, line)
      Report.urls(line).include?(note["url"]) && line.scan(/[“"]([^”"]+)[”"]/).flatten.any? { |quote| quote.size >= 20 && note["text"].to_s.include?(quote) }
    end

    def security
      @report.security.filter_map do |name, version, line|
        "#{name} #{version}: Security needs an advisory link or a linked quote from collected notes" unless security_evidence?(name, version, line)
      end
    end
  end
end
