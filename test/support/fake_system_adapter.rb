class FakeSystemAdapter
  attr_reader :operations, :filesystem, :exit_statuses

  def initialize
    @operations = []
    @filesystem = {}
    @exit_statuses = []
    @command_outputs = {}
  end

  def stub_file_content(path, content)
    @filesystem[File.expand_path(path)] = content
  end

  def stub_command_output(command, output, exit_status: 0)
    @command_outputs[command] = {output: output, exit_status: exit_status}
  end

  def file_exist?(path)
    @operations << [:file_exist?, path]
    return false if path.nil?
    @filesystem.key?(File.expand_path(path))
  end

  def dir_exist?(path)
    @operations << [:dir_exist?, path]
    path = File.expand_path(path)
    @filesystem.key?(path) || @filesystem.keys.any? { |k| k.start_with?("#{path}/") }
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

  def glob(pattern)
    @operations << [:glob, pattern]
    @filesystem.keys.select { |k| File.fnmatch?(pattern, k, File::FNM_PATHNAME) }
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
