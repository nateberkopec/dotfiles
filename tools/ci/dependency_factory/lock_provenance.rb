require "toml-rb"
module DependencyFactory
  class LockProvenance
    def initialize(content)
      @tools = TomlRB.parse(content).fetch("tools", {})
    end

    def lost_since(previous)
      (previous.attested - attested).map { |tool, platform| "#{tool} #{platform}" }
    end

    protected

    def attested
      @tools.flat_map do |tool, records|
        [records].flatten.flat_map do |record|
          dotted = record.select { |key, _| key.start_with?("platforms.") }.transform_keys { |key| key.delete_prefix("platforms.") }
          record.fetch("platforms", {}).merge(dotted).filter_map { |platform, info| [tool, platform] if info["provenance"] }
        end
      end.uniq
    end
  end
end
