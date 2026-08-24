require "test_helper"
require "open3"

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
      assert_last_thirty_logs_remain(logs_dir, removed: ["dotf_2000-01-01_00-00-00.log"])
    end
  end

  def test_upgrade_command_is_removed
    with_dotf_script do |_tmpdir, script_path, _logs_dir|
      refute system("bash", script_path, "upgrade", out: File::NULL, err: File::NULL)
    end
  end

  def test_mise_uses_apt_for_system_packages_on_debian
    with_dotf_script do |_tmpdir, script_path, _logs_dir|
      assert_equal "apt", mise_system_packages_manager(script_path, "DOTF_FORCE_DEBIAN")
    end
  end

  def test_mise_uses_brew_for_system_packages_elsewhere
    with_dotf_script do |_tmpdir, script_path, _logs_dir|
      assert_equal "brew", mise_system_packages_manager(script_path, "DOTF_FORCE_NON_DEBIAN")
    end
  end

  def test_mise_bootstrap_includes_packages_for_admin_macos
    with_dotf_script do |tmpdir, script_path, _logs_dir|
      stdout, stderr, status, log = mise_bootstrap_result(tmpdir, script_path, admin: true)

      assert status.success?
      assert_includes stdout, "Converging machine with mise bootstrap"
      refute_includes stdout, "mise -C"
      assert_empty stderr
      assert_equal "mise -C #{tmpdir}/home bootstrap --yes --locked --quiet\n", log
    end
  end

  def test_mise_bootstrap_shows_output_when_debugging
    with_dotf_script do |tmpdir, script_path, _logs_dir|
      stdout, _stderr, status, log = mise_bootstrap_result(tmpdir, script_path, admin: true, debug: true)

      assert status.success?
      assert_includes stdout, "mise -C"
      assert_equal "mise -C #{tmpdir}/home bootstrap --yes --locked\n", log
    end
  end

  def test_mise_bootstrap_skips_packages_for_non_admin_macos
    with_dotf_script do |tmpdir, script_path, _logs_dir|
      _stdout, stderr, status, log = mise_bootstrap_result(tmpdir, script_path, admin: false, exit_status: 23)

      assert_equal 23, status.exitstatus
      assert_includes stderr, "mise failed"
      assert_includes log, "mise -C #{tmpdir}/home bootstrap --yes --locked --skip packages --quiet\n"
    end
  end

  def test_mise_bootstrap_includes_packages_on_debian
    with_dotf_script do |tmpdir, script_path, _logs_dir|
      _stdout, _stderr, status, log = mise_bootstrap_result(tmpdir, script_path, admin: false, debian: true)

      assert status.success?
      assert_equal "mise -C #{tmpdir}/home bootstrap --yes --locked --quiet\n", log
    end
  end

  def test_acquire_dotf_lock_blocks_second_live_holder
    with_dotf_script do |tmpdir, script_path, _logs_dir|
      lock_dir = File.join(tmpdir, "dotf.lock")
      escaped_script = Shellwords.escape(script_path)
      escaped_lock = Shellwords.escape(lock_dir)
      holder_cmd = "source #{escaped_script}; export DOTF_LOCK_DIR=#{escaped_lock}; acquire_dotf_lock; sleep 2"
      holder = IO.popen(["bash", "-c", holder_cmd])
      begin
        sleep 0.5
        second = system({"DOTF_LOCK_DIR" => lock_dir}, "bash", "-c", "source #{escaped_script}; acquire_dotf_lock", out: File::NULL, err: File::NULL)
        refute second
      ensure
        begin
          Process.kill("TERM", holder.pid)
        rescue
          nil
        end
        holder.wait
      end
    end
  end

  def test_acquire_dotf_lock_recovers_stale_lock
    with_dotf_script do |tmpdir, script_path, _logs_dir|
      lock_dir = File.join(tmpdir, "dotf.lock")
      FileUtils.mkdir_p(lock_dir)
      File.write(File.join(lock_dir, "pid"), "999999")
      escaped_script = Shellwords.escape(script_path)

      assert system({"DOTF_LOCK_DIR" => lock_dir}, "bash", "-c", "source #{escaped_script}; acquire_dotf_lock", out: File::NULL)
    end
  end

  def test_run_runs_existing_machine_migrations_before_setup_steps
    with_dotf_script do |tmpdir, script_path, _logs_dir|
      log_path = File.join(tmpdir, "run-commands.log")
      File.write(File.join(tmpdir, "bin", "bootstrap"), bootstrap_stub(log_path))
      FileUtils.chmod("+x", File.join(tmpdir, "bin", "bootstrap"))
      command = run_function_command(script_path, log_path)

      stdout, status = Open3.capture2e("bash", "-c", command)

      assert status.success?
      refute_includes stdout, "Running migration"
      assert_run_commands(log_path)
      assert_equal "test-sha\n", File.read(File.join(tmpdir, "state", "dotfiles", "last-run-sha"))
    end
  end

  def test_record_successful_run_does_nothing_outside_a_git_checkout
    with_dotf_script do |tmpdir, script_path, _logs_dir|
      state_home = File.join(tmpdir, "state")
      command = "source #{Shellwords.escape(script_path)}; record_successful_run"

      assert system({"XDG_STATE_HOME" => state_home}, "bash", "-c", command)
      refute Dir.exist?(File.join(state_home, "dotfiles"))
    end
  end

  private

  def mise_bootstrap_result(tmpdir, script_path, admin:, debian: false, exit_status: 0, debug: false)
    home = File.join(tmpdir, "home")
    log_path = File.join(tmpdir, "mise-bootstrap.log")
    command = <<~BASH
      source #{Shellwords.escape(script_path)}
      export HOME=#{Shellwords.escape(home)} LOG_FILE=#{Shellwords.escape(log_path)}
      mise() {
        printf 'mise %s\n' "$*"
        if [ #{exit_status} -ne 0 ]; then
          printf 'mise failed\n' >&2
        fi
        return #{exit_status}
      }
      run_mise_bootstrap
    BASH
    platform = debian ? "DOTF_FORCE_DEBIAN" : "DOTF_FORCE_NON_DEBIAN"
    stdout, stderr, status = Open3.capture3(
      {platform => "true", "DOTF_FORCE_ADMIN" => admin.to_s, "DEBUG" => debug.to_s, "PATH" => "/usr/bin:/bin"},
      "bash", "-c", command
    )
    [stdout, stderr, status, File.read(log_path)]
  end

  def mise_system_packages_manager(script_path, platform_override)
    command = "source #{Shellwords.escape(script_path)}; ensure_mise_env; printf %s \"$MISE_SYSTEM_PACKAGES_MANAGERS\""
    IO.popen({platform_override => "true", "PATH" => "/usr/bin:/bin"}, ["bash", "-c", command], &:read)
  end

  def assert_last_thirty_logs_remain(logs_dir, removed: ["dotf_2000-01-01_00-00-00.log", "dotf_2000-01-01_00-00-01.log"])
    dotf_logs = current_dotf_logs(logs_dir)
    assert_equal 30, dotf_logs.size
    removed.each { |log| refute_includes dotf_logs, log }
    assert_includes dotf_logs, "dotf_2000-01-01_00-00-30.log"
    assert File.exist?(File.join(logs_dir, "other.log"))
  end

  def assert_run_commands(log_path)
    commands = File.readlines(log_path, chomp: true)
    assert_equal "bootstrap", commands[0]
    assert_equal "mise activate bash", commands[1]
    assert_match(/\Amise -C .+ bootstrap --yes --locked/, commands[2])
    assert_equal "mise activate bash", commands[3]
    assert_match(/\Aruby -r \.\/lib\/dotfiles\.rb -e Dotfiles::MigrationRunner\.new\('.+'\)\.run_if_existing_machine\z/, commands[4])
    assert_match(/\Aruby -r \.\/lib\/dotfiles\.rb -e Dotfiles::Runner\.new\('.+'\)\.run\z/, commands[5])
    assert_equal 6, commands.size
  end

  def bootstrap_stub(log_path)
    <<~BASH
      #!/bin/bash
      echo bootstrap >> #{Shellwords.escape(log_path)}
    BASH
  end

  def run_function_command(script_path, log_path)
    escaped_script = Shellwords.escape(script_path)
    escaped_log = Shellwords.escape(log_path)
    <<~BASH
      source #{escaped_script}
      export HOME=#{Shellwords.escape(File.join(File.dirname(escaped_log), "home"))}
      export XDG_STATE_HOME=#{Shellwords.escape(File.join(File.dirname(escaped_log), "state"))}
      export DOTF_LOCK_DIR=#{Shellwords.escape(File.join(File.dirname(escaped_log), "dotf.lock"))}
      git() {
        printf 'test-sha\n'
      }
      mise() {
        printf 'mise %s\\n' "$*" >> #{escaped_log}
      }
      ruby() {
        printf 'ruby %s\\n' "$*" >> #{escaped_log}
        [[ "$*" != *MigrationRunner* ]] || echo "Running migration 1: Test"
      }
      cmd_run
    BASH
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
