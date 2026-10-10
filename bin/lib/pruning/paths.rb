require "digest"

module ManagedPruning
  class Paths
    UnsafeParent = Class.new(RuntimeError)

    def initialize(root)
      @root = File.realpath(root)
    end

    def validate(relative)
      parts = relative.split("/")
      raise "Unsafe pruning path: #{relative}" if relative.empty? || relative.start_with?("/") || parts.any? { |part| ["", ".", ".."].include?(part) }
      parts
    end

    def resolve(relative)
      validate(relative)[0...-1].reduce(@root) do |parent, part|
        child = File.join(parent, part)
        raise UnsafeParent, "Symlinked pruning parent: #{child}" if File.symlink?(child)
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

    def same_entry?(left, right)
      left_path = resolve(left)
      right_path = resolve(right)
      left_stat = File.lstat(left_path)
      right_stat = File.lstat(right_path)
      return false unless [left_stat.dev, left_stat.ino] == [right_stat.dev, right_stat.ino]
      return false unless File.identical?(File.dirname(left_path), File.dirname(right_path))

      left_name = File.basename(left_path)
      right_name = File.basename(right_path)
      names = Dir.children(File.dirname(left_path))
      left_name == right_name || !(names.include?(left_name) && names.include?(right_name))
    rescue Errno::ENOENT, Errno::ENOTDIR, UnsafeParent
      false
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
