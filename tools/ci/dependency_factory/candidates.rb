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
      found = pinned.uniq(&:name).filter_map { |pin| candidate(pin) }
      gems, others = found.partition { |candidate| candidate["kind"] == "gem" && candidate["name"] != "bundler" }
      others << batch(gems) unless gems.empty?
      {"generated_at" => @now.utc.iso8601, "minimum_release_age_days" => @days, "candidates" => others,
       "observation_only" => observed.map { |pin| observation(pin) }}
    end

    private

    def skip_reason(pin)
      return "unpinned" if pin.kind == "unpinned"
      "not a stable version" unless Versions.stable?(pin.current)
    end

    def observation(pin)
      {"name" => pin.name, "manifest" => pin.manifest, "current" => pin.current, "reason" => skip_reason(pin)}
    end

    def candidate(pin)
      releases = releases_for(pin)
      eligible = newest_after(Versions.eligible(releases, @cutoff), pin.current)
      latest = newest_after(Versions.latest(releases), eligible)
      return if latest == pin.current
      pin.to_h.slice(:name, :kind, :manifest, :current).transform_keys(&:to_s).merge(
        "eligible" => eligible, "latest" => latest, "published" => Versions.published(releases, [eligible, latest]),
        "source" => source_url(releases, (eligible == pin.current) ? latest : eligible)
      )
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
