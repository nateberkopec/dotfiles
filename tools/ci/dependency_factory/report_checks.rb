require "time"

module DependencyFactory
  class ReportChecks
    def initialize(candidates:, report:, changes:, snoozes:)
      @data = candidates
      @report = report
      @changes = changes
      @snoozes = snoozes
      @cutoff = Time.iso8601(candidates.fetch("generated_at")) - (candidates.fetch("minimum_release_age_days") * 86_400)
    end

    def errors
      [coverage, gated, updates, unreported_changes, member_changes, snoozed].flatten
    end

    private

    def candidates
      @data.fetch("candidates")
    end

    def members
      candidates.flat_map { |candidate| candidate["members"] || [] }
    end

    def by_name
      @by_name ||= (candidates + members).to_h { |candidate| [candidate["name"], candidate] }
    end

    def rows(title)
      @report.rows(title)
    end

    def tools(title)
      rows(title).map { |row| Report.tool(row["Tool"]) }
    end

    def coverage
      mentioned = Report::TABLES.keys.flat_map { |title| tools(title) }
      candidates.reject { |candidate| mentioned.include?(candidate["name"]) }.map { |candidate| "#{candidate["name"]} is a candidate but appears in no table" }
    end

    def gated
      (candidates + members).select { |candidate| candidate["latest"] != candidate["eligible"] && !skipped?(candidate) }.map do |candidate|
        "#{candidate["name"]} #{candidate["latest"]} is newer than the eligible release and must appear under Skipped candidates"
      end
    end

    def skipped?(candidate)
      rows("Skipped candidates").any? { |row| Report.tool(row["Tool"]) == candidate["name"] && row["Candidate"].to_s.include?(candidate["latest"]) }
    end

    def updates
      rows("Updates").flat_map { |row| update_errors(Report.tool(row["Tool"]), row) }
    end

    def update_errors(name, row)
      candidate = by_name[name]
      return ["#{name} is in Updates but is not a candidate"] unless candidate
      return batch_errors(row) if candidate["kind"] == "gem-lock"
      [("#{name}: Old must be #{candidate["current"]}" unless row["Old"] == candidate["current"]),
        *version_errors(name, candidate, row["New"]),
        ("#{name}: the diff does not change this pin to #{row["New"]}" unless @changes[name]&.last == row["New"])].compact
    end

    def version_errors(name, candidate, version)
      [("#{name}: #{version} is not newer than #{candidate["current"]}" unless Versions.newer?(version, candidate["current"])),
        ("#{name}: #{version} is newer than the eligible #{candidate["eligible"]}" if Versions.newer?(version, candidate["eligible"])),
        *age_errors(name, candidate, version)].compact
    end

    def age_errors(name, candidate, version)
      date = candidate["published"][version]
      return [] unless date && Time.iso8601(date) > @cutoff
      ["#{name} #{version} was published #{date}, inside the #{@data["minimum_release_age_days"]}-day release gate"]
    end

    def batch_errors(row)
      [("#{Candidates::BATCH}: the diff does not change #{Candidates::BATCH}" unless @changes[Candidates::BATCH]),
        ("#{Candidates::BATCH}: New must be regenerated" unless row["New"] == "regenerated")].compact
    end

    def unreported_changes
      allowed = tools("Updates") + members.map { |member| member["name"] }
      @changes.keys.reject { |name| allowed.include?(name) || new_gem?(name) }.map { |name| "#{name} changed in the diff without an Updates row" }
    end

    def new_gem?(name)
      @changes[name].first.nil? && @changes[Candidates::BATCH] && tools("Updates").include?(Candidates::BATCH)
    end

    def member_changes
      members.flat_map { |member| @changes[member["name"]] ? version_errors(member["name"], member, @changes[member["name"]].last) : [] }
    end

    def snoozed
      unknown = rows("Snoozed candidates").reject { |row| @snoozes.key?(Report.tool(row["Tool"])) }
      unknown.map { |row| "#{Report.tool(row["Tool"])} is in Snoozed candidates but not in #{CONFIG_PATH}" } + @snoozes.flat_map { |tool, snooze| snooze_errors(tool, snooze) }
    end

    def snooze_errors(tool, snooze)
      candidate = by_name[tool]
      return [] unless candidate && !woken?(tool, snooze, candidate)
      [("#{tool} #{snooze["candidate"]} is snoozed in #{CONFIG_PATH} but missing from Snoozed candidates" unless snoozed_row?(tool, snooze)),
        ("#{tool} is snoozed but changed in the diff" if @changes[tool])].compact
    end

    def snoozed_row?(tool, snooze)
      rows("Snoozed candidates").any? { |row| Report.tool(row["Tool"]) == tool && row["Candidate"].to_s.include?(snooze["candidate"]) }
    end

    def woken?(tool, snooze, candidate)
      security = (rows("Updates") + rows("Skipped candidates")).any? { |row| Report.tool(row["Tool"]) == tool && row["Security"] == "true" }
      security || !Versions.newer?(snooze["wake_at"], candidate["eligible"])
    end
  end
end
