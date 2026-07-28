require "securerandom"

class Dotfiles
  class DebianDesktopSourceInstaller
    def initialize(system: Dotfiles::SystemAdapter.new)
      @system = system
    end

    def install(source = {})
      return false unless complete?(source)
      keyring = "/usr/share/keyrings/#{source["name"]}-archive-keyring.gpg"
      list = "/etc/apt/sources.list.d/#{source["name"]}.list"
      keyring_exists = @system.file_exist?(keyring)
      list_current = current_list?(list, source["line"])
      return true if keyring_exists && list_current
      temporary = temporary_paths
      return false unless keyring_exists || install_key(source["key_url"], keyring, temporary)
      return false unless list_current || install_list(source["line"], list, temporary.last)
      true
    ensure
      @system.rm_rf(temporary) if temporary
    end

    private

    def complete?(source)
      source.values_at("name", "key_url", "line").all? { |value| !value.to_s.empty? }
    end

    def current_list?(path, line)
      @system.file_exist?(path) && @system.read_file(path).strip == line
    end

    def install_key(url, destination, temporary)
      return false unless succeeds?(["curl", "-fsSL", url, "-o", temporary[0]])
      return false unless succeeds?(["gpg", "--dearmor", "--output", temporary[1], temporary[0]])
      succeeds?(["sudo", "install", "-m", "644", temporary[1], destination])
    end

    def install_list(line, destination, temporary)
      @system.write_file(temporary, "#{line}\n")
      succeeds?(["sudo", "install", "-m", "644", temporary, destination])
    end

    def succeeds?(command)
      @system.execute(command).last == 0
    end

    def temporary_paths
      base = "/tmp/dotfiles-debian-source-#{SecureRandom.hex(6)}"
      ["#{base}.key", "#{base}.gpg", "#{base}.list"]
    end
  end
end
