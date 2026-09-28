module DependencyFactory
  class ChangedPins
    def initialize(base:, root: ROOT, show: nil, read: nil)
      @base = base
      @root = root
      @show = show || method(:git_show)
      @read = read || method(:read_file)
    end

    def changes
      contents = Manifests::PATHS.to_h { |path| [path, [@show.call(@base, path), @read.call(path)]] }
      pins = contents.flat_map { |path, (before, after)| pins_at(path, before) + pins_at(path, after) }
      duplicates = pins.group_by(&:name).select { |_, group| group.map(&:manifest).uniq.size > 1 }.keys
      contents.each_with_object({}) do |(path, (before, after)), changes|
        changes[Candidates::BATCH] = ["changed", "changed"] if path == Candidates::BATCH && before != after
        changed_pins(path, before, after).each { |pin, versions| changes[Manifests.key(pin, duplicates)] = versions }
      end
    end

    private

    def changed_pins(path, before, after)
      old_pins = pins_at(path, before).to_h { |pin| [pin.name, pin.current] }
      pins_at(path, after).filter_map { |pin| [pin, [old_pins[pin.name], pin.current]] if old_pins[pin.name] != pin.current }
    end

    def pins_at(path, content)
      return [] if content.to_s.strip.empty?
      Manifests.pins(path, content)
    end

    def git_show(base, path)
      Sources.capture({}, "git", "-C", @root, "show", "#{base}:#{path}")
    end

    def read_file(path)
      File.read(File.join(@root, path))
    end
  end
end
