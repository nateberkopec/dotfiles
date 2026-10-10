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
      paths = source_paths(source)
      return {"files" => {}, "desired" => []} if paths.empty?
      targets = paths.map { |path| target(item, source, path) }
      files = paths.zip(targets).to_h do |path, destination|
        [destination, deployed(item, path, destination, mode)]
      end.compact
      artifacts = (Array(item["artifacts"]) + @hooks.artifacts(item["hook"])).uniq
      artifacts.each do |path|
        fingerprint = target_fingerprint(item, path)
        files[path] = fingerprint if fingerprint
      end
      {"files" => files, "desired" => targets + artifacts, "hook" => item["hook"]}
    end

    def source_paths(source)
      stat = source_stat(source)
      stat ? walk_source(source, stat) : []
    end

    def source_stat(source)
      File.lstat(source)
    rescue Errno::ENOENT
      nil
    end

    def walk_source(path, stat = File.lstat(path))
      return [path] unless stat.directory?

      Dir.children(path).sort.flat_map { |name| walk_source(File.join(path, name)) }
    end

    def target(item, source, path)
      suffix = path.delete_prefix(source)
      item.fetch("target") + suffix
    end

    def deployed(item, source, target, mode)
      relative = source.delete_prefix(@root + "/")
      expected = @source.fingerprint(relative) || raise("Pruning source disappeared: #{relative}")
      actual = target_fingerprint(item, target)
      matches = if mode == "symlink"
        actual && actual["type"] == "symlink" && File.realpath(@home.resolve(target)) == File.realpath(source)
      else
        actual == expected
      end
      return actual if matches && (!item["optional"] || File.writable?(@home.resolve(target)))
      return nil if item["optional"]

      raise "Managed file was not successfully deployed: #{target}"
    end

    def target_fingerprint(item, target)
      @home.fingerprint(target)
    rescue Paths::UnsafeParent => error
      raise unless item["optional"]
      warn "Skipping optional pruning target #{target}: #{error.message}"
      nil
    end
  end
end
