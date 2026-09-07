module DependencyFactory
  class ChangedPins
    def initialize(base:, root: ROOT, show: nil, read: nil)
      @base = base
      @root = root
      @show = show || method(:git_show)
      @read = read || method(:read_file)
    end

    def changes
      Manifests::PATHS.each_with_object({}) do |path, changes|
        before, after = @show.call(@base, path), @read.call(path)
        changed_pins(path, before, after).each { |name, versions| changes[name] = versions }
      end
    end

    private

    def changed_pins(path, before, after)
      old_pins, new_pins = pins_at(path, before), pins_at(path, after)
      (old_pins.keys | new_pins.keys).filter_map { |name| [name, [old_pins[name], new_pins[name]]] if old_pins[name] != new_pins[name] }
    end

    def pins_at(path, content)
      return {} if content.to_s.strip.empty?
      Manifests.pins(path, content).to_h { |pin| [pin.name, pin.current] }
    end

    def git_show(base, path)
      Sources.capture({}, "git", "-C", @root, "show", "#{base}:#{path}")
    end

    def read_file(path)
      File.read(File.join(@root, path))
    end
  end
end
