require "yaml"

module ManagedPruning
  class Inventory
    def initialize(root, home, hooks)
      @root = root
      @source = Paths.new(root)
      @home = home
      @hooks = hooks
    end

    def read
      config = YAML.safe_load_file(File.join(@root, "config/pruning.yml"))
      raise "Unsupported pruning configuration" unless config.fetch("version") == 1
      raise "Missing deployment source" unless File.directory?(@source.resolve("files/home"))

      config.fetch("items").transform_values { |item| inventory(item) }
    end

    private

    def inventory(item)
      @hooks.validate(item["hook"])
      source = @source.resolve(item.fetch("source"))
      mode = item.fetch("mode", "copy")
      raise "Unknown pruning mode: #{mode}" unless ["copy", "symlink"].include?(mode)
      return {"files" => {}, "desired" => []} unless File.exist?(source) || File.symlink?(source)

      paths = source_paths(source)
      targets = paths.map { |path| target(item, source, path) }
      files = paths.zip(targets).to_h do |path, destination|
        [destination, deployed(item, path, destination, mode)]
      end.compact
      artifacts = (Array(item["artifacts"]) + @hooks.artifacts(item["hook"])).uniq
      artifacts.each do |path|
        fingerprint = @home.fingerprint(path)
        files[path] = fingerprint if fingerprint
      end
      {"files" => files, "desired" => targets + artifacts, "hook" => item["hook"]}
    end

    def source_paths(source)
      return [source] unless File.directory?(source)
      raise "Symlinked pruning source: #{source}" if File.symlink?(source)

      Dir.glob(File.join(source, "**", "*"), File::FNM_DOTMATCH).reject do |path|
        File.directory?(path) && !File.symlink?(path)
      end
    end

    def target(item, source, path)
      suffix = path.delete_prefix(source)
      item.fetch("target") + suffix
    end

    def deployed(item, source, target, mode)
      relative = source.delete_prefix(@root + "/")
      expected = @source.fingerprint(relative)
      actual = @home.fingerprint(target)
      matches = if mode == "symlink"
        actual && actual["type"] == "symlink" && File.realpath(@home.resolve(target)) == File.realpath(source)
      else
        actual == expected
      end
      return actual if matches && (!item["optional"] || File.writable?(@home.resolve(target)))
      return nil if item["optional"]

      raise "Managed file was not successfully deployed: #{target}"
    end
  end
end
