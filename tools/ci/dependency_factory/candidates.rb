require "time"

module DependencyFactory
  class Candidates
    BATCH = "Gemfile.lock"

    def initialize(sources:, days:, now: Time.now)
      @sources = sources
      @days = days
      @now = now
      @cutoff = now - (days * 86_400)
    end

    def build(pins)
      observed, pinned = pins.partition { |pin| skip_reason(pin) }
      duplicates = pins.group_by(&:name).select { |_, group| group.map(&:manifest).uniq.size > 1 }.keys
      found = pinned.uniq { |pin| [pin.name, pin.manifest] }.filter_map { |pin| candidate(pin, duplicates) }
      gems, others = found.partition { |candidate| candidate["kind"] == "gem" && candidate["name"] != "bundler" }
      others << batch(gems) unless gems.empty?
      {"generated_at" => @now.utc.iso8601, "minimum_release_age_days" => @days, "candidates" => others,
       "observation_only" => observed.map { |pin| observation(pin, duplicates) }}
    end

    private

    def skip_reason(pin)
      return "unpinned" if pin.kind == "unpinned"
      "not a stable version" unless Versions.stable?(pin.current)
    end

    def observation(pin, duplicates)
      {"name" => Manifests.key(pin, duplicates), "manifest" => pin.manifest, "current" => pin.current, "reason" => skip_reason(pin)}
    end

    def candidate(pin, duplicates)
      releases = releases_for(pin)
      eligible = newest_after(Versions.eligible(releases, @cutoff), pin.current)
      latest = newest_after(Versions.latest(releases), eligible)
      return if latest == pin.current
      candidate_identity(pin, duplicates).merge(
        "eligible" => eligible, "latest" => latest, "published" => Versions.published(releases, [eligible, latest]),
        "meta" => pin.meta, "releases" => release_range(releases, pin.current, latest),
        "source" => source_url(releases, (eligible == pin.current) ? latest : eligible)
      )
    end

    def candidate_identity(pin, duplicates)
      pin.to_h.slice(:name, :kind, :manifest, :current).transform_keys(&:to_s).merge(
        "name" => Manifests.key(pin, duplicates), "tool" => pin.name
      )
    end

    def release_range(releases, current, latest)
      releases.select do |release|
        version = release["version"]
        Versions.stable?(version) && Versions.newer?(version, current) && !Versions.newer?(version, latest)
      end.uniq { |release| release["version"] }.sort_by { |release| Versions.parse(release["version"]) }
    end

    def newest_after(version, floor)
      (version && Versions.newer?(version, floor)) ? version : floor
    end

    def releases_for(pin)
      case pin.kind
      when "mise" then @sources.mise(pin.name.sub(/\[.*\]\z/, ""))
      when "npm" then @sources.npm(pin.meta["package"])
      when "gem" then @sources.gem(pin.name)
      else @sources.github_releases(pin.meta["repo"], pin.meta["tag_prefix"])
      end
    end

    def source_url(releases, version)
      releases.find { |release| release["version"] == version }&.fetch("release_url", nil)
    end

    def batch(members)
      {"name" => BATCH, "kind" => "gem-lock", "manifest" => BATCH, "current" => "#{members.size} gems behind",
       "eligible" => "regenerated", "latest" => "regenerated", "published" => {}, "source" => "https://rubygems.org", "members" => members}
    end
  end
end
