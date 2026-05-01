require "test_helper"
require "fileutils"
require "shellwords"
require "tmpdir"

# standard:disable Dotfiles/BanFileSystemClasses
class DotfCliTest < Minitest::Test
  def test_init_logging_keeps_only_last_thirty_dotf_logs
    with_dotf_script do |tmpdir, script_path, logs_dir|
      seed_dotf_logs(logs_dir)

      log_file_record = File.join(tmpdir, "log-file-path")
      source_script_and_init_logging(script_path, log_file_record)

      assert_last_thirty_logs_remain(logs_dir)
      assert File.exist?(File.read(log_file_record).chomp)
    end
  end

  def test_every_dotf_invocation_rotates_logs
    with_dotf_script do |_tmpdir, script_path, logs_dir|
      seed_dotf_logs(logs_dir)

      assert system("bash", script_path, "help", out: File::NULL)

      dotf_logs = current_dotf_logs(logs_dir)
      assert_equal 30, dotf_logs.size
      refute_includes dotf_logs, "dotf_2000-01-01_00-00-00.log"
      assert_includes dotf_logs, "dotf_2000-01-01_00-00-30.log"
      assert File.exist?(File.join(logs_dir, "other.log"))
    end
  end

  def test_upgrade_updates_pi_extensions
    with_dotf_script do |tmpdir, script_path, _logs_dir|
      bin_dir = File.join(tmpdir, "fake-bin")
      log_path = File.join(tmpdir, "upgrade-commands.log")
      FileUtils.mkdir_p(bin_dir)
      %w[mise brew pi].each { |command| write_command_stub(bin_dir, command) }

      with_env("DOTF_UPGRADE_LOG" => log_path, "PATH" => "#{bin_dir}:/usr/bin:/bin") do
        assert system("bash", script_path, "upgrade", out: File::NULL)
      end

      assert_equal [
        "brew shellenv bash",
        "mise activate bash",
        "mise cache clear --yes",
        "mise plugins update",
        "mise outdated --bump",
        "mise up --yes",
        "mise install --yes",
        "pi update --extensions",
        "mise prune --yes",
        "mise cache prune --yes",
        "brew update",
        "brew upgrade",
        "brew autoremove",
        "brew cleanup"
      ], File.readlines(log_path, chomp: true)
    end
  end

  private

  def with_dotf_script
    Dir.mktmpdir("dotf-log-rotation") do |tmpdir|
      bin_dir = File.join(tmpdir, "bin")
      logs_dir = File.join(tmpdir, "logs")
      FileUtils.mkdir_p(bin_dir)
      FileUtils.mkdir_p(logs_dir)

      script_path = File.join(bin_dir, "dotf")
      FileUtils.cp(File.expand_path("../../bin/dotf", __dir__), script_path)

      yield tmpdir, script_path, logs_dir
    end
  end

  def seed_dotf_logs(logs_dir)
    31.times do |index|
      File.write(File.join(logs_dir, format("dotf_2000-01-01_00-00-%02d.log", index)), "old")
    end
    File.write(File.join(logs_dir, "other.log"), "keep")
  end

  def write_command_stub(bin_dir, command)
    path = File.join(bin_dir, command)
    File.write(path, <<~BASH)
      #!/bin/bash
      printf '%s %s\n' "#{command}" "$*" >> "$DOTF_UPGRADE_LOG"
    BASH
    FileUtils.chmod("+x", path)
  end

  def source_script_and_init_logging(script_path, log_file_record)
    command = [
      "source #{Shellwords.escape(script_path)}",
      "init_logging",
      "printf '%s\\n' \"$LOG_FILE\" > #{Shellwords.escape(log_file_record)}"
    ].join("; ")

    assert system("bash", "-c", command)
  end

  def assert_last_thirty_logs_remain(logs_dir)
    dotf_logs = current_dotf_logs(logs_dir)
    assert_equal 30, dotf_logs.size
    refute_includes dotf_logs, "dotf_2000-01-01_00-00-00.log"
    refute_includes dotf_logs, "dotf_2000-01-01_00-00-01.log"
    assert_includes dotf_logs, "dotf_2000-01-01_00-00-30.log"
    assert File.exist?(File.join(logs_dir, "other.log"))
  end

  def current_dotf_logs(logs_dir)
    Dir.children(logs_dir).grep(/\Adotf_.*\.log\z/)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
