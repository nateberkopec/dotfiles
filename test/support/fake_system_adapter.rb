class FakeSystemAdapter
  attr_reader :operations, :filesystem, :exit_statuses

  def initialize
    @operations = []
    @filesystem = {}
    @exit_statuses = []
    @command_outputs = {}
    @macos = false
    @linux = false
    @debian = false
  end

  def macos?
    @macos
  end

  def linux?
    @linux
  end

  def debian?
    @debian
  end

  def running_container?
    @running_container || false
  end

  def stub_macos(value = true)
    @macos = value
  end

  def stub_linux(value = true)
    @linux = value
  end

  def stub_debian(value = true)
    @debian = value
    @linux = value
  end

  def stub_running_container(value = true)
    @running_container = value
  end

  def stub_file_content(path, content)
    @filesystem[File.expand_path(path)] = content
  end

  def stub_symlink(path, target)
    @filesystem[File.expand_path(path)] = {symlink: target}
  end

  def stub_command(command, output, exit_status = 0)
    if output.is_a?(Array)
      output_str, status = output
    elsif exit_status.is_a?(Hash)
      output_str = output
      status = exit_status[:exit_status] || 0
    else
      output_str = output
      status = exit_status
    end
    @command_outputs[command] = {output: output_str, exit_status: status}
  end

  def file_exist?(path)
    @operations << [:file_exist?, path]
    return false if path.nil?
    @filesystem.key?(File.expand_path(path))
  end

  def dir_exist?(path)
    @operations << [:dir_exist?, path]
    path = File.expand_path(path)
    (@filesystem[path] == :directory) || @filesystem.keys.any? { |k| k.start_with?("#{path}/") }
  end

  def symlink?(path)
    @operations << [:symlink?, path]
    entry = @filesystem[File.expand_path(path)]
    entry.is_a?(Hash) && entry.key?(:symlink)
  end

  def readlink(path)
    @operations << [:readlink, path]
    entry = @filesystem[File.expand_path(path)]
    raise Errno::EINVAL, path unless entry.is_a?(Hash) && entry.key?(:symlink)
    entry[:symlink]
  end

  def create_symlink(target, link_path)
    @operations << [:create_symlink, target, link_path]
    @filesystem[File.expand_path(link_path)] = {symlink: target}
  end

  def read_file(path)
    @operations << [:read_file, path]
    @filesystem[File.expand_path(path)] || raise(Errno::ENOENT, path)
  end

  def write_file(path, content)
    @operations << [:write_file, path, content]
    @filesystem[File.expand_path(path)] = content
  end

  def mkdir_p(path)
    @operations << [:mkdir_p, path]
    return if path.nil?
    @filesystem[File.expand_path(path)] = :directory
  end

  def cp(src, dest)
    @operations << [:cp, src, dest]
    return if src.nil? || dest.nil?
    src_path = File.expand_path(src)
    dest_path = File.expand_path(dest)
    @filesystem[dest_path] = @filesystem[src_path]
  end

  def cp_r(src, dest)
    @operations << [:cp_r, src, dest]
    src_path = File.expand_path(src)
    dest_path = File.expand_path(dest)
    @filesystem[dest_path] = @filesystem[src_path]
  end

  def rm_rf(paths)
    paths = [paths] unless paths.is_a?(Array)
    paths.each do |path|
      @operations << [:rm_rf, path]
      expanded = File.expand_path(path)
      @filesystem.delete(expanded)
      @filesystem.delete_if { |k, _v| k.start_with?("#{expanded}/") }
    end
  end

  def chmod(mode, path)
    @operations << [:chmod, mode, path]
  end

  def glob(pattern, flags = 0)
    @operations << [:glob, pattern, flags]
    fnmatch_flags = File::FNM_PATHNAME | File::FNM_EXTGLOB | flags
    @filesystem.keys.select { |k| File.fnmatch?(pattern, k, fnmatch_flags) }
  end

  def chdir(path)
    @operations << [:chdir, path]
    yield if block_given?
  end

  def readlines(path)
    @operations << [:readlines, path]
    content = @filesystem[File.expand_path(path)] || raise(Errno::ENOENT, path)
    content.split("\n").map { |line| "#{line}\n" }
  end

  def execute(command, quiet: true)
    @operations << [:execute, command, {quiet: quiet}]

    stub = @command_outputs[command]
    if stub
      @exit_statuses << stub[:exit_status]
      [stub[:output].strip, stub[:exit_status]]
    else
      @exit_statuses << 0
      ["", 0]
    end
  end

  def execute!(command, quiet: true)
    @operations << [:execute!, command, {quiet: quiet}]

    stub = @command_outputs[command]
    if stub
      @exit_statuses << stub[:exit_status]
      raise "Command failed: #{command}\nOutput: #{stub[:output]}" unless stub[:exit_status] == 0
      [stub[:output].strip, stub[:exit_status]]
    else
      @exit_statuses << 0
      ["", 0]
    end
  end

  def operation_count(operation_name)
    @operations.count { |(op, *_)| op == operation_name }
  end

  def received_operation?(operation_name, *args)
    if args.empty?
      @operations.any? { |(op, *_)| op == operation_name }
    else
      @operations.any? { |(op, *op_args)| op == operation_name && op_args == args }
    end
  end
end
