require "toml-rb"

module DependencyFactory
  class LockProvenance
    def initialize(content)
      @tools = TomlRB.parse(content).fetch("tools", {})
    end

    def lost_since(previous)
      previous.attested.filter_map do |key, before|
        after = attested[key]
        next if after && after[:provenance] == before[:provenance]
        change(key, "provenance", before[:provenance], after&.fetch(:provenance))
      end
    end

    def verified_by(native, platform)
      native.verified_on(platform).filter_map do |tool, identity|
        next if verified_on(platform).key?(tool)
        "#{tool} #{platform}: provenance verified natively for #{artifact(identity)}"
      end
    end

    def unverified_by(native, platform)
      verified_on(platform).filter_map do |tool, identity|
        reproduced = native.verified_on(platform)[tool]
        next if reproduced == identity
        field = identity_difference(identity, reproduced)
        "#{tool} #{platform}: #{field} does not match the natively verified artifact"
      end
    end

    protected

    def attested
      @attested ||= entries.select { |_, info| info[:provenance] }
    end

    def verified_on(platform)
      attested.filter_map { |(tool, key), info| [tool, info] if key == platform && info[:verified] }.to_h
    end

    private

    def entries
      @tools.each_with_object({}) do |(tool, records), entries|
        [records].flatten.each do |record|
          platforms(record).each do |platform, info|
            entries[[tool, platform]] = {
              provenance: info["provenance"],
              verified: info["provenance_verified"] == true,
              version: record["version"],
              checksum: info["checksum"]
            }
          end
        end
      end
    end

    def platforms(record)
      dotted = record.select { |key, _| key.start_with?("platforms.") }.transform_keys { |key| key.delete_prefix("platforms.") }
      record.fetch("platforms", {}).merge(dotted)
    end

    def change(key, field, before, after)
      "#{key.join(" ")} #{field}: #{before.inspect} -> #{after.inspect}"
    end

    def identity_difference(expected, actual)
      return "provenance_verified: true -> false" unless actual
      field = %i[provenance version checksum].find { |name| expected[name] != actual[name] }
      "#{field}: #{expected[field].inspect} -> #{actual[field].inspect}"
    end

    def artifact(identity)
      "version #{identity[:version].inspect}, checksum #{identity[:checksum].inspect}"
    end
  end
end
