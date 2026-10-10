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
      preserve_artifact_baselines(previous, current)
      desired = current.values.flat_map { |item| item.fetch("desired") }
      verified = current.values.flat_map { |item| item.fetch("files").keys }
      @active_hooks = active_hooks(previous, current)
      result = current.transform_values { |item| item.except("desired", "artifacts") }
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

    def active_hooks(previous, current)
      current.values.filter_map do |item|
        hook = item["hook"]
        next unless hook
        retained = previous.values.any? do |prior|
          prior["hook"] == hook && !carried_files(prior, item.fetch("desired")).empty?
        end
        hook if item.fetch("files").any? || retained
      end
    end

    def preserve_artifact_baselines(previous, current)
      owned = previous.values.flat_map { |item| item.fetch("files").to_a }
      current.each_value do |item|
        item.fetch("artifacts", []).each do |target|
          next unless item.fetch("files").key?(target)
          claims = owned.select { |path, _| path == target || @home.same_entry?(path, target) }
          fingerprints = claims.map(&:last).uniq
          raise "Conflicting artifact ownership: #{target}" if fingerprints.length > 1
          item["files"][target] = fingerprints.first unless fingerprints.empty?
        end
      end
    end

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
        old_parts = path.split("/")
        new_parts = replacement.split("/")
        depth = [old_parts.length, new_parts.length].min
        @home.same_entry?(old_parts.take(depth).join("/"), new_parts.take(depth).join("/"))
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
