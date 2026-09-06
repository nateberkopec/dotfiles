require "json"

module DependencyFactory
  # The ledger is the factual part of a report; prose has no prescribed layout.
  class Report
    MARKER = /<!-- dependency-decisions\n(.*?)\n-->/m

    def initialize(body)
      matches = body.scan(MARKER)
      @data = (matches.size == 1) ? JSON.parse(matches.first.first) : {}
    rescue JSON::ParserError
      @data = {}
    end

    def decisions
      @data.fetch("decisions", [])
    end

    def errors
      return ["Expected one dependency-decisions JSON ledger"] unless @data.is_a?(Hash) && @data.keys.sort == %w[decisions outcome]
      return ["Invalid outcome"] unless %w[ready blocked deferred researched].include?(@data["outcome"])
      return ["Invalid decisions"] unless decisions.is_a?(Array) && decisions.all? { |row| valid?(row) }
      keys = decisions.map { |row| row.values_at("name", "version") }
      (keys.uniq == keys) ? [] : ["Duplicate decisions"]
    end

    private

    def valid?(row)
      row.is_a?(Hash) && %w[name version reason].all? { |key| row[key].is_a?(String) && !row[key].strip.empty? } &&
        %w[update defer].include?(row["action"]) && [true, false, "unknown"].include?(row["security"]) &&
        (row["security"] != true || row["quote"].is_a?(String)) && row.key?("source") && (row["source"].nil? || row["source"].is_a?(String))
    end
  end
end
