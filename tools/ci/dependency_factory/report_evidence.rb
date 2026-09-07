module DependencyFactory
  class ReportEvidence
    def initialize(notes)
      @notes = notes
    end

    def errors(row, pin)
      name, version = row.values_at("name", "version")
      note = (@notes[name] || []).find { |entry| entry["version"] == version && entry["url"] == row["source"] }
      [("#{name} #{version}: source is not collected evidence" unless collected?(row, pin)),
        ("#{name} #{version}: unavailable notes require unknown security" unless usable?(note) || row["security"] == "unknown"),
        ("#{name} #{version}: security requires an exact collected quote" if row["security"] == true && !quoted?(row, note))].compact
    end

    private

    def collected?(row, pin)
      records = (@notes[row["name"]] || []) + (pin ? pin.fetch("releases", []) : [])
      sources = records.filter_map { |entry| entry["url"] || entry["release_url"] if entry["version"] == row["version"] }
      return sources.include?(row["source"]) unless row["source"].nil?
      row["action"] == "defer" && row["security"] == "unknown" && pin && sources.empty?
    end

    def usable?(note)
      note && !note["error"] && !note["text"].to_s.strip.empty?
    end

    def quoted?(row, note)
      quote = row["quote"].to_s
      usable?(note) && quote.size >= 20 && note["text"].include?(quote)
    end
  end
end
