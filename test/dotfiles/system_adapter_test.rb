require "test_helper"
require "rbconfig"
require "stringio"
require "tmpdir"

# standard:disable Dotfiles/BanFileSystemClasses
class SystemAdapterTest < Minitest::Test
  class TestSystemAdapter < Dotfiles::SystemAdapter
    attr_reader :calls

    def initialize
      @calls = []
    end

    def execute_quiet(command)
      @calls << [:quiet, command]
      ["quiet", 0]
    end

    def execute_verbose(command)
      @calls << [:verbose, command]
      ["verbose", 0]
    end
  end

  class MissingCommandSystemAdapter < Dotfiles::SystemAdapter
    def execute_quiet(_command)
      raise Errno::ENOENT, "missing-command"
    end

    def execute_verbose(_command)
      raise Errno::ENOENT, "missing-command"
    end
  end

  def test_execute_uses_quiet_path_by_default
    adapter = TestSystemAdapter.new

    output, status = adapter.execute("echo hi")

    assert_equal ["quiet", 0], [output, status]
    assert_equal [[:quiet, "echo hi"]], adapter.calls
  end

  def test_execute_streams_output_when_debug_is_true
    adapter = TestSystemAdapter.new

    with_env("DEBUG" => "true") do
      output, status = adapter.execute("echo hi")

      assert_equal ["verbose", 0], [output, status]
    end

    assert_equal [[:verbose, "echo hi"]], adapter.calls
  end

  def test_execute_honors_explicit_verbose_calls
    adapter = TestSystemAdapter.new

    output, status = adapter.execute("echo hi", quiet: false)

    assert_equal ["verbose", 0], [output, status]
    assert_equal [[:verbose, "echo hi"]], adapter.calls
  end

  def test_execute_returns_127_when_quiet_command_is_missing
    adapter = MissingCommandSystemAdapter.new

    output, status = adapter.execute("missing-command")

    assert_equal 127, status
    assert_includes output, "missing-command"
  end

  def test_execute_returns_127_when_verbose_command_is_missing
    adapter = MissingCommandSystemAdapter.new

    output, status = adapter.execute("missing-command", quiet: false)

    assert_equal 127, status
    assert_includes output, "missing-command"
  end

  def test_execute_quiet_captures_stdout_stderr_and_status
    adapter = Dotfiles::SystemAdapter.new
    command = [RbConfig.ruby, "-e", "$stdout.sync = true; $stderr.sync = true; $stdout.print('out'); warn 'err'; exit 7"]

    output, status = adapter.execute_quiet(command)

    assert_equal 7, status
    assert_includes output, "out"
    assert_includes output, "err"
  end

  def test_execute_verbose_streams_output_and_returns_status
    adapter = Dotfiles::SystemAdapter.new
    command = [RbConfig.ruby, "-e", "$stdout.sync = true; $stderr.sync = true; puts 'alpha'; warn 'beta'; exit 3"]

    stdout, = capture_io do
      output, status = adapter.execute_verbose(command)

      assert_equal 3, status
      assert_includes output, "alpha"
      assert_includes output, "beta"
    end

    assert_includes stdout, "alpha"
    assert_includes stdout, "beta"
  end

  def test_execute_treats_array_arguments_as_literals
    with_tmpdir do |tmpdir|
      adapter = Dotfiles::SystemAdapter.new
      output_path = File.join(tmpdir, "output.txt")
      sentinel_path = File.join(tmpdir, "sentinel")
      value = "path with spaces and 'quotes'; touch #{sentinel_path}"
      command = [RbConfig.ruby, "-e", "File.write(ARGV[0], ARGV[1])", output_path, value]

      _output, status = adapter.execute(command)

      assert_equal 0, status
      assert_equal value, File.read(output_path)
      refute File.exist?(sentinel_path)
    end
  end

  def test_execute_bang_returns_output_for_successful_command
    adapter = Dotfiles::SystemAdapter.new
    command = [RbConfig.ruby, "-e", "print 'done'"]

    output, status = adapter.execute!(command)

    assert_equal ["done", 0], [output, status]
  end

  def test_execute_bang_raises_for_failed_command
    adapter = Dotfiles::SystemAdapter.new
    command = [RbConfig.ruby, "-e", "warn 'boom'; exit 5"]

    error = assert_raises RuntimeError do
      adapter.execute!(command)
    end

    assert_includes error.message, "Command failed"
    assert_includes error.message, "boom"
  end

  def test_hostname_delegates_to_socket
    stub_singleton_method(Socket, :gethostname, "stubbed-host") do
      assert_equal "stubbed-host", Dotfiles::SystemAdapter.new.hostname
    end
  end

  def test_running_codespaces_is_true_when_env_is_true
    with_env("CODESPACES" => "true") do
      assert Dotfiles::SystemAdapter.new.running_codespaces?
    end
  end

  def test_running_codespaces_is_false_by_default
    with_env("CODESPACES" => nil) do
      refute Dotfiles::SystemAdapter.new.running_codespaces?
    end
  end

  def test_running_container_detects_dockerenv
    adapter = Dotfiles::SystemAdapter.new

    stub_singleton_method(File, :exist?, ->(path) { path == "/.dockerenv" }) do
      assert adapter.running_container?
    end
  end

  def test_running_container_detects_docker_in_cgroup
    adapter = Dotfiles::SystemAdapter.new

    stub_singleton_method(File, :exist?, ->(path) { path == "/proc/1/cgroup" }) do
      stub_singleton_method(File, :read, "12:memory:/docker/abc123") do
        assert adapter.running_container?
      end
    end
  end

  def test_running_container_is_false_without_markers
    adapter = Dotfiles::SystemAdapter.new

    stub_singleton_method(File, :exist?, false) do
      refute adapter.running_container?
    end
  end

  def test_write_and_read_file
    with_tmpdir do |tmpdir|
      path = File.join(tmpdir, "example.txt")
      adapter = Dotfiles::SystemAdapter.new

      adapter.write_file(path, "hello")

      assert_equal "hello", adapter.read_file(path)
      assert adapter.file_exist?(path)
    end
  end

  def test_mkdir_p_and_dir_exist
    with_tmpdir do |tmpdir|
      path = File.join(tmpdir, "a", "b", "c")
      adapter = Dotfiles::SystemAdapter.new

      refute adapter.dir_exist?(path)
      adapter.mkdir_p(path)

      assert adapter.dir_exist?(path)
    end
  end

  def test_create_symlink_and_readlink
    with_tmpdir do |tmpdir|
      target = File.join(tmpdir, "target.txt")
      link = File.join(tmpdir, "link.txt")
      adapter = Dotfiles::SystemAdapter.new
      File.write(target, "payload")

      adapter.create_symlink(target, link)

      assert adapter.symlink?(link)
      assert_equal target, adapter.readlink(link)
    end
  end

  def test_cp_copies_file_contents
    with_tmpdir do |tmpdir|
      source = File.join(tmpdir, "source.txt")
      destination = File.join(tmpdir, "destination.txt")
      adapter = Dotfiles::SystemAdapter.new
      File.write(source, "copied")

      adapter.cp(source, destination)

      assert_equal "copied", File.read(destination)
    end
  end

  def test_cp_r_copies_directories_recursively
    with_tmpdir do |tmpdir|
      source = File.join(tmpdir, "source")
      destination = File.join(tmpdir, "destination")
      nested = File.join(source, "nested")
      adapter = Dotfiles::SystemAdapter.new
      FileUtils.mkdir_p(nested)
      File.write(File.join(nested, "file.txt"), "copied recursively")

      adapter.cp_r(source, destination)

      assert_equal "copied recursively", File.read(File.join(destination, "nested", "file.txt"))
    end
  end

  def test_rm_rf_removes_files_and_directories
    with_tmpdir do |tmpdir|
      directory = File.join(tmpdir, "remove-me")
      file = File.join(directory, "file.txt")
      adapter = Dotfiles::SystemAdapter.new
      FileUtils.mkdir_p(directory)
      File.write(file, "gone")

      adapter.rm_rf(directory)

      refute File.exist?(directory)
      refute File.exist?(file)
    end
  end

  def test_chmod_updates_file_permissions
    with_tmpdir do |tmpdir|
      path = File.join(tmpdir, "mode.txt")
      adapter = Dotfiles::SystemAdapter.new
      File.write(path, "mode")

      adapter.chmod(0o600, path)

      assert_equal 0o600, File.stat(path).mode & 0o777
    end
  end

  def test_glob_returns_matching_paths
    with_tmpdir do |tmpdir|
      adapter = Dotfiles::SystemAdapter.new
      FileUtils.mkdir_p(File.join(tmpdir, "nested"))
      first = File.join(tmpdir, "one.rb")
      second = File.join(tmpdir, "nested", "two.rb")
      File.write(first, "puts :one")
      File.write(second, "puts :two")

      matches = adapter.glob(File.join(tmpdir, "**", "*.rb")).sort

      assert_equal [first, second].sort, matches
    end
  end

  def test_chdir_runs_block_in_requested_directory
    with_tmpdir do |tmpdir|
      adapter = Dotfiles::SystemAdapter.new
      original_dir = Dir.pwd

      seen_dir = adapter.chdir(tmpdir) { Dir.pwd }

      assert_equal File.realpath(tmpdir), File.realpath(seen_dir)
      assert_equal original_dir, Dir.pwd
    end
  end

  def test_readlines_returns_each_line_with_trailing_newline
    with_tmpdir do |tmpdir|
      path = File.join(tmpdir, "lines.txt")
      adapter = Dotfiles::SystemAdapter.new
      File.write(path, "one\ntwo\n")

      assert_equal ["one\n", "two\n"], adapter.readlines(path)
    end
  end

  private

  def with_tmpdir
    Dir.mktmpdir("system-adapter-test") do |tmpdir|
      yield tmpdir
    end
  end

  def stub_singleton_method(object, method_name, return_value)
    singleton_class = object.singleton_class
    backup_name = :"__stubbed_original_#{method_name}_#{object_id}"
    had_original = object.respond_to?(method_name)

    preserve_singleton_method(singleton_class, backup_name, method_name) if had_original
    replace_singleton_method(singleton_class, method_name, return_value)

    yield
  ensure
    restore_singleton_method(singleton_class, method_name, backup_name, had_original)
  end

  def preserve_singleton_method(singleton_class, backup_name, method_name)
    singleton_class.send(:alias_method, backup_name, method_name)
  end

  def replace_singleton_method(singleton_class, method_name, return_value)
    remove_singleton_method(singleton_class, method_name)
    singleton_class.send(:define_method, method_name, &singleton_method_stub(return_value))
  end

  def singleton_method_stub(return_value)
    lambda do |*args, **kwargs, &block|
      if return_value.respond_to?(:call)
        return_value.call(*args, **kwargs, &block)
      else
        return_value
      end
    end
  end

  def restore_singleton_method(singleton_class, method_name, backup_name, had_original)
    remove_singleton_method(singleton_class, method_name)
    return unless had_original

    singleton_class.send(:alias_method, method_name, backup_name)
    remove_singleton_method(singleton_class, backup_name)
  end

  def remove_singleton_method(singleton_class, method_name)
    singleton_class.send(:remove_method, method_name)
  rescue NameError
    nil
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
