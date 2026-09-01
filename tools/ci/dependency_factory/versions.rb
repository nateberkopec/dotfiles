require "time"

module DependencyFactory
  module Versions
    STABLE = /\A\d+(?:\.\d+)*[a-z]?\z/

    module_function

    def stable?(version)
      version.to_s.match?(STABLE)
    end

    def parse(version)
      Gem::Version.new(version)
    rescue ArgumentError
      Gem::Version.new("0")
    end

    def newer?(candidate, current)
      parse(candidate) > parse(current)
    end

    def max(versions)
      versions.max_by { |version| parse(version) }
    end

    def latest(releases)
      max(releases.map { |release| release["version"] }.select { |version| stable?(version) })
    end

    def eligible(releases, cutoff)
      aged = releases.select { |release| stable?(release["version"]) && released_by?(release, cutoff) }
      max(aged.map { |release| release["version"] })
    end

    def released_by?(release, cutoff)
      release["created_at"] && Time.iso8601(release["created_at"]) <= cutoff
    end

    def published(releases, versions)
      releases.each_with_object({}) do |release, dates|
        dates[release["version"]] = release["created_at"] if versions.include?(release["version"])
      end
    end

    def patch_bump?(old, new)
      before, after = parse(old).segments, parse(new).segments
      before.size >= 3 && before.size == after.size && before[0..-2] == after[0..-2]
    end
  end
end
