require "fileutils"
require "json"
require "tempfile"

module ManagedPruning
  class Ledger
    def initialize(home, hooks)
      @home = home
      @hooks = hooks
      state_home = ENV.fetch("XDG_STATE_HOME", File.join(ENV.fetch("HOME"), ".local/state"))
      @directory = File.join(state_home, "dotfiles")
      raise "Symlinked pruning ledger directory" if File.symlink?(@directory)
      FileUtils.mkdir_p(@directory, mode: 0o700)
      @path = File.join(@directory, "deployed.json")
    end

    def synchronize
      flags = File::RDWR | File::CREAT | File::NOFOLLOW
      File.open(File.join(@directory, "pruning.lock"), flags, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        yield
      end
    end

    def read
      raise "Symlinked pruning ledger" if File.symlink?(@path)
      return {} unless File.exist?(@path)

      data = JSON.parse(File.read(@path))
      raise "Unsupported pruning ledger" unless data.fetch("version") == 1
      items = data.fetch("items")
      items.each_value { |item| validate(item) }
      items
    end

    def write(items)
      Tempfile.create(["deployed", ".json"], @directory) do |file|
        file.write(JSON.pretty_generate({"version" => 1, "items" => items}) + "\n")
        file.flush
        file.fsync
        File.rename(file.path, @path)
      end
    end

    private

    def validate(item)
      @hooks.validate(item["hook"])
      item.fetch("files").each do |path, fingerprint|
        @home.validate(path)
        case fingerprint.fetch("type")
        when "file"
          raise "Invalid file fingerprint" unless fingerprint.fetch("sha256").match?(/\A[0-9a-f]{64}\z/)
        when "symlink"
          raise "Invalid symlink fingerprint" unless fingerprint.fetch("target").is_a?(String)
        else
          raise "Unknown ledger file type"
        end
      end
    end
  end
end
