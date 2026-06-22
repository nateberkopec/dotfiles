require "test_helper"

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

  def test_upgrade_updates_pi_extensions
    assert_upgrade_commands(
      stubs: %w[mise brew pi],
      env: {"DOTF_FORCE_NON_DEBIAN" => "true"},
      expected: [
        "brew shellenv bash", "mise activate bash", "mise cache clear --yes", "mise plugins update",
        "mise outdated --json",
        "mise up --dry-run --before 3d --yes", "mise up --before 3d --yes",
        "mise install --before 3d --yes", "pi update --extensions",
        "mise prune --yes", "mise cache prune --yes", "MISE_EXPERIMENTAL=1 mise system install --help",
        "MISE_EXPERIMENTAL=1 mise system install --yes --update",
        "HOMEBREW_AUTO_UPDATE_SECS=604800 brew update-if-needed",
        "HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade",
        "HOMEBREW_NO_AUTO_UPDATE=1 brew autoremove", "HOMEBREW_NO_AUTO_UPDATE=1 brew cleanup"
      ]
    )
  end

  def test_upgrade_runs_on_debian_without_homebrew
    assert_upgrade_commands(
      stubs: %w[mise apt-get],
      env: {"DOTF_FORCE_DEBIAN" => "true", "DOTF_SKIP_SUDO" => "true"},
      expected: [
        "mise activate bash", "mise cache clear --yes", "mise plugins update",
        "mise outdated --json",
        "mise up --dry-run --before 3d --yes", "mise up --before 3d --yes",
        "mise install --before 3d --yes", "mise prune --yes", "mise cache prune --yes",
        "MISE_EXPERIMENTAL=1 mise system install --help", "MISE_EXPERIMENTAL=1 mise system install --yes --update"
      ]
    )
  end

  def test_run_runs_migrations_before_setup_steps
    with_dotf_script do |tmpdir, script_path, _logs_dir|
      log_path = File.join(tmpdir, "run-commands.log")
      File.write(File.join(tmpdir, "bin", "bootstrap"), bootstrap_stub(log_path))
      FileUtils.chmod("+x", File.join(tmpdir, "bin", "bootstrap"))
      command = run_function_command(script_path, log_path)

      assert system("bash", "-c", command, out: File::NULL)

      assert_run_commands(log_path)
    end
  end

  private

  def assert_upgrade_commands(stubs:, expected:, env: {})
    with_dotf_script do |tmpdir, script_path, _logs_dir|
      bin_dir = File.join(tmpdir, "fake-bin")
      log_path = File.join(tmpdir, "upgrade-commands.log")
      FileUtils.mkdir_p(bin_dir)
      stubs.each { |command| write_command_stub(bin_dir, command) }

      with_env(env.merge("DOTF_UPGRADE_LOG" => log_path, "PATH" => "#{bin_dir}:/usr/bin:/bin")) do
        clean_homebrew_env = {"HOMEBREW_AUTO_UPDATE_SECS" => nil, "HOMEBREW_NO_AUTO_UPDATE" => nil}
        assert system(clean_homebrew_env, "bash", script_path, "upgrade", out: File::NULL)
      end

      assert_equal expected, File.readlines(log_path, chomp: true)
    end
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
    assert_match(/\Aruby -r \.\/lib\/dotfiles\.rb -e Dotfiles::MigrationRunner\.new\('.+'\)\.run\z/, commands[2])
    assert_match(/\Aruby -r \.\/lib\/dotfiles\.rb -e Dotfiles::Runner\.new\('.+'\)\.run\z/, commands[3])
    assert_equal 4, commands.size
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
      mise() { printf 'mise %s\\n' "$*" >> #{escaped_log}; }
      ruby() { printf 'ruby %s\\n' "$*" >> #{escaped_log}; }
      cmd_run
    BASH
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
