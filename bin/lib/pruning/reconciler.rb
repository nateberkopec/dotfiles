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
      result = current.transform_values { |item| item.except("desired") }
      conflicts = []
      previous.each do |id, item|
        stale = item.fetch("files").keys - desired
        pending = retire(id, item, stale, current, conflicts)
        entry = result[id] ||= {"files" => {}, "hook" => item["hook"]}
        active = current.fetch(id, {"desired" => []}).fetch("desired")
        entry["hook"] = item["hook"] if active.empty?
        unchanged = item.fetch("files").slice(*active)
        entry["files"] = unchanged.merge(pending).merge(entry.fetch("files"))
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

    def retire(id, item, stale, current, conflicts)
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
      active = current.fetch(id, {"desired" => []})
      retired = active.fetch("desired").empty?
      @hooks.run(item["hook"]) if retired && !stale.empty?
      stale.each { |path| @home.remove(path, files.fetch(path)) }
      {}
    rescue SystemCallError, RuntimeError => error
      conflicts << id
      warn "Cannot prune #{id}: #{error.message}"
      files
    end
  end
end
