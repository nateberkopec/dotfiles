require "test_helper"

class Dotfiles::SystemAdapterTest < Minitest::Test
  def setup
    @adapter = Dotfiles::SystemAdapter.new
    @test_dir = File.join(Dir.tmpdir, "dotfiles_test_#{Process.pid}")
    FileUtils.mkdir_p(@test_dir)
  end

  def teardown
    FileUtils.rm_rf(@test_dir) if File.exist?(@test_dir)
  end

  def test_file_exist_returns_true_for_existing_file
    file_path = File.join(@test_dir, "test.txt")
    File.write(file_path, "content")
    assert @adapter.file_exist?(file_path)
  end

  def test_file_exist_returns_false_for_nonexistent_file
    refute @adapter.file_exist?(File.join(@test_dir, "nonexistent.txt"))
  end

  def test_dir_exist_returns_true_for_existing_directory
    assert @adapter.dir_exist?(@test_dir)
  end

  def test_dir_exist_returns_false_for_nonexistent_directory
    refute @adapter.dir_exist?(File.join(@test_dir, "nonexistent"))
  end

  def test_read_file_returns_file_contents
    file_path = File.join(@test_dir, "test.txt")
    File.write(file_path, "hello world")
    assert_equal "hello world", @adapter.read_file(file_path)
  end

  def test_write_file_creates_file_with_content
    file_path = File.join(@test_dir, "output.txt")
    @adapter.write_file(file_path, "test content")
    assert_equal "test content", File.read(file_path)
  end

  def test_write_file_overwrites_existing_file
    file_path = File.join(@test_dir, "output.txt")
    File.write(file_path, "old content")
    @adapter.write_file(file_path, "new content")
    assert_equal "new content", File.read(file_path)
  end

  def test_mkdir_p_creates_directory
    new_dir = File.join(@test_dir, "subdir", "nested")
    @adapter.mkdir_p(new_dir)
    assert Dir.exist?(new_dir)
  end

  def test_mkdir_p_does_not_fail_if_directory_exists
    @adapter.mkdir_p(@test_dir)
    assert Dir.exist?(@test_dir)
  end

  def test_cp_copies_file
    src = File.join(@test_dir, "source.txt")
    dest = File.join(@test_dir, "dest.txt")
    File.write(src, "content")
    @adapter.cp(src, dest)
    assert_equal "content", File.read(dest)
  end

  def test_cp_r_copies_directory_recursively
    src_dir = File.join(@test_dir, "source")
    dest_dir = File.join(@test_dir, "destination")
    FileUtils.mkdir_p(File.join(src_dir, "nested"))
    File.write(File.join(src_dir, "file.txt"), "content")
    File.write(File.join(src_dir, "nested", "nested_file.txt"), "nested content")

    @adapter.cp_r(src_dir, dest_dir)

    assert File.exist?(File.join(dest_dir, "file.txt"))
    assert File.exist?(File.join(dest_dir, "nested", "nested_file.txt"))
    assert_equal "content", File.read(File.join(dest_dir, "file.txt"))
    assert_equal "nested content", File.read(File.join(dest_dir, "nested", "nested_file.txt"))
  end

  def test_rm_rf_removes_file
    file_path = File.join(@test_dir, "to_remove.txt")
    File.write(file_path, "content")
    @adapter.rm_rf(file_path)
    refute File.exist?(file_path)
  end

  def test_rm_rf_removes_directory_recursively
    dir_to_remove = File.join(@test_dir, "to_remove")
    FileUtils.mkdir_p(File.join(dir_to_remove, "nested"))
    File.write(File.join(dir_to_remove, "file.txt"), "content")

    @adapter.rm_rf(dir_to_remove)

    refute Dir.exist?(dir_to_remove)
  end

  def test_chmod_changes_file_permissions
    file_path = File.join(@test_dir, "perms.txt")
    File.write(file_path, "content")
    @adapter.chmod(0o600, file_path)
    assert_equal 0o600, File.stat(file_path).mode & 0o777
  end

  def test_glob_finds_matching_files
    File.write(File.join(@test_dir, "test1.txt"), "content")
    File.write(File.join(@test_dir, "test2.txt"), "content")
    File.write(File.join(@test_dir, "other.log"), "content")

    results = @adapter.glob(File.join(@test_dir, "*.txt"))

    assert_equal 2, results.length
    assert results.all? { |f| f.end_with?(".txt") }
  end

  def test_glob_returns_empty_array_when_no_matches
    results = @adapter.glob(File.join(@test_dir, "*.nonexistent"))
    assert_equal [], results
  end

  def test_chdir_changes_directory_temporarily
    original_dir = Dir.pwd
    new_dir = @test_dir

    @adapter.chdir(new_dir) do
      assert_equal File.realpath(new_dir), File.realpath(Dir.pwd)
    end

    assert_equal original_dir, Dir.pwd
  end

  def test_readlines_returns_array_of_lines
    file_path = File.join(@test_dir, "lines.txt")
    File.write(file_path, "line1\nline2\nline3")

    lines = @adapter.readlines(file_path)

    assert_equal ["line1\n", "line2\n", "line3"], lines
  end

  def test_execute_returns_output_and_exit_status
    output, status = @adapter.execute("echo hello")
    assert_equal "hello", output
    assert_equal 0, status
  end

  def test_execute_returns_nonzero_status_on_failure
    _, status = @adapter.execute("false")
    assert_equal 1, status
  end

  def test_execute_with_quiet_false_returns_output
    output, status = @adapter.execute("echo test", quiet: false)
    assert_equal "test", output
    assert_equal 0, status
  end

  def test_execute_captures_stderr_when_quiet
    output, _status = @adapter.execute("ruby -e 'warn \"error\"'", quiet: true)
    assert_includes output, "error"
  end

  def test_execute_bang_returns_output_and_status_on_success
    output, status = @adapter.execute!("echo success")
    assert_equal "success", output
    assert_equal 0, status
  end

  def test_execute_bang_raises_on_failure
    error = assert_raises(RuntimeError) do
      @adapter.execute!("false")
    end
    assert_includes error.message, "Command failed: false"
  end

  def test_execute_bang_with_quiet_false_raises_on_failure
    error = assert_raises(RuntimeError) do
      @adapter.execute!("false", quiet: false)
    end
    assert_includes error.message, "Command failed: false"
  end

  def test_path_join_combines_path_parts
    result = @adapter.path_join("home", "user", "file.txt")
    assert_equal File.join("home", "user", "file.txt"), result
  end

  def test_path_join_handles_single_part
    result = @adapter.path_join("single")
    assert_equal "single", result
  end

  def test_path_dirname_returns_directory_name
    result = @adapter.path_dirname("/home/user/file.txt")
    assert_equal "/home/user", result
  end

  def test_path_dirname_returns_dot_for_basename_only
    result = @adapter.path_dirname("file.txt")
    assert_equal ".", result
  end
end
