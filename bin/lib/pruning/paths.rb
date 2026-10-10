require "digest"

module ManagedPruning
  class Paths
    def initialize(root)
      @root = File.realpath(root)
    end

    def resolve(relative)
      parts = relative.split("/")
      raise "Unsafe pruning path: #{relative}" if relative.empty? || relative.start_with?("/") || parts.any? { |part| ["", ".", ".."].include?(part) }

      parts[0...-1].reduce(@root) do |parent, part|
        child = File.join(parent, part)
        raise "Symlinked pruning parent: #{child}" if File.symlink?(child)
        child
      end
      File.join(@root, relative)
    end

    def fingerprint(relative)
      path = resolve(relative)
      stat = File.lstat(path)
      return {"type" => "symlink", "target" => File.readlink(path)} if stat.symlink?
      raise "Not a regular managed file: #{path}" unless stat.file?

      {"type" => "file", "sha256" => Digest::SHA256.file(path).hexdigest}
    rescue Errno::ENOENT
      nil
    end

    def remove(relative, expected)
      actual = fingerprint(relative)
      raise "Retired file changed during cleanup: #{relative}" unless actual.nil? || actual == expected
      path = resolve(relative)
      File.unlink(path) if File.exist?(path) || File.symlink?(path)
      puts "Pruned #{relative}"
      remove_empty_parents(File.dirname(path))
    end

    private

    def remove_empty_parents(path)
      while path != @root
        Dir.rmdir(path)
        path = File.dirname(path)
      end
    rescue Errno::ENOTEMPTY, Errno::EEXIST, Errno::ENOENT, Errno::EACCES, Errno::EPERM
      nil
    end
  end
end
