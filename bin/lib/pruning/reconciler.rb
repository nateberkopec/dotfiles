module ManagedPruning
  class Reconciler
    def initialize(home, hooks, ledger)
      @home = home
      @hooks = hooks
      @ledger = ledger
    end

    def run(current)
      previous = @ledger.read
      validate_hooks(previous, current)
      desired = current.values.flat_map { |item| item.fetch("desired") }
      verified = current.values.flat_map { |item| item.fetch("files").keys }
      @active_hooks = current.values.filter_map { |item| item["hook"] unless item.fetch("files").empty? }
      result = current.transform_values { |item| item.except("desired") }
      conflicts = []
      previous.each do |id, item|
        carried = carried_files(item, desired - verified)
        stale = (item.fetch("files").keys - desired - carried.keys).reject { |path| replaced?(path, verified) }
        pending = retire(id, item, stale, conflicts)
        entry = result[id] ||= {"files" => {}, "hook" => item["hook"]}
        active = current.fetch(id, {"desired" => []}).fetch("desired")
        entry["hook"] = item["hook"] if active.empty?
        entry["files"] = carried.merge(pending).merge(entry.fetch("files"))
      end
      result.delete_if { |_, item| item.fetch("files").empty? }
      @ledger.write(result)
      raise "Pruning incomplete: #{conflicts.join(", ")}" unless conflicts.empty?
    end

    private

    def validate_hooks(previous, current)
      previous.each do |id, item|
        active = current.fetch(id, {"desired" => []})
        next if active.fetch("desired").empty? || active["hook"] == item["hook"]
        raise "Cleanup hook changed for #{id}; use a new pruning item name"
      end
    end

    def carried_files(item, unverified)
      item.fetch("files").select do |path, _|
        unverified.any? { |target| path == target || @home.same_entry?(path, target) }
      end
    end

    def replaced?(path, verified)
      verified.any? do |replacement|
        path.start_with?(replacement + "/") || replacement.start_with?(path + "/") || @home.same_entry?(path, replacement)
      end
    end

    def retire(id, item, stale, conflicts)
      files = item.fetch("files").slice(*stale)
      modified = stale.reject do |path|
        actual = @home.fingerprint(path)
        actual.nil? || actual == files.fetch(path)
      end
      unless modified.empty?
        conflicts.concat(modified)
        warn "Preserving modified retired files: #{modified.join(", ")}"
        return files
      end
      @hooks.run(item["hook"]) if !stale.empty? && !@active_hooks.include?(item["hook"])
      stale.each { |path| @home.remove(path, files.fetch(path)) }
      {}
    rescue SystemCallError, RuntimeError => error
      conflicts << id
      warn "Cannot prune #{id}: #{error.message}"
      files
    end
  end
end
