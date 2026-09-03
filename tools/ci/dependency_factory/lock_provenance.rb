require "toml-rb"

module DependencyFactory
  class LockProvenance
    def initialize(content)
      @tools = TomlRB.parse(content).fetch("tools", {})
    end

    def lost_since(previous)
      (previous.attested.keys - attested.keys).map { |tool, platform| "#{tool} #{platform}" }
    end

    def verified_by(native, platform)
      native.verified_on(platform).reject { |tool| verified_on(platform).include?(tool) }
        .map { |tool| "#{tool} #{platform}: provenance verified natively" }
    end

    def unverified_by(native, platform)
      verified_on(platform).reject { |tool| native.verified_on(platform).include?(tool) }
        .map { |tool| "#{tool} #{platform}: provenance_verified could not be reproduced natively" }
    end

    protected

    def attested
      @attested ||= entries.select { |_, info| info["provenance"] }.transform_values { |info| info["provenance_verified"] == true }
    end

    def verified_on(platform)
      attested.filter_map { |(tool, key), verified| tool if key == platform && verified }
    end

    private

    def entries
      @tools.each_with_object({}) do |(tool, records), entries|
        [records].flatten.each { |record| platforms(record).each { |platform, info| entries[[tool, platform]] = info } }
      end
    end

    def platforms(record)
      dotted = record.select { |key, _| key.start_with?("platforms.") }.transform_keys { |key| key.delete_prefix("platforms.") }
      record.fetch("platforms", {}).merge(dotted)
    end
  end
end
