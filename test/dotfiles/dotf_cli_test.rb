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
      env: {
        "DOTF_FORCE_NON_DEBIAN" => "true",
        "DOTF_MANAGED_BREW_FORMULAE" => "duti,fish",
        "DOTF_BREW_OUTDATED_FORMULAE" => "duti,unmanaged"
      },
      expected: [
        "brew shellenv bash", "mise activate bash", "mise cache clear --yes", "mise plugins update",
        "mise outdated --json",
        "mise up --dry-run --before 3d --yes", "mise up --before 3d --yes",
        "mise install --before 3d --yes", "pi update --extensions",
        "mise prune --yes", "mise cache prune --yes", "MISE_EXPERIMENTAL=1 mise system install --help",
        "MISE_EXPERIMENTAL=1 mise system install --yes --update",
        "HOMEBREW_AUTO_UPDATE_SECS=604800 brew update-if-needed",
        "HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --formula --quiet",
        "HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade duti",
        "HOMEBREW_NO_AUTO_UPDATE=1 brew cleanup duti"
      ]
    )
  end

  def test_upgrade_skips_brew_upgrade_when_no_managed_formulae_are_outdated
    assert_upgrade_commands(
      stubs: %w[mise brew],
      env: {
        "DOTF_FORCE_NON_DEBIAN" => "true",
        "DOTF_MANAGED_BREW_FORMULAE" => "duti",
        "DOTF_BREW_OUTDATED_FORMULAE" => "unmanaged"
      },
      expected: [
        "brew shellenv bash", "mise activate bash", "mise cache clear --yes", "mise plugins update",
        "mise outdated --json",
        "mise up --dry-run --before 3d --yes", "mise up --before 3d --yes",
        "mise install --before 3d --yes", "mise prune --yes", "mise cache prune --yes",
        "MISE_EXPERIMENTAL=1 mise system install --help",
        "MISE_EXPERIMENTAL=1 mise system install --yes --update",
        "HOMEBREW_AUTO_UPDATE_SECS=604800 brew update-if-needed",
        "HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --formula --quiet"
      ]
    )
  end

  def test_outdated_reports_mise_and_managed_homebrew_updates
    with_dotf_script do |tmpdir, script_path, _logs_dir|
      bin_dir = File.join(tmpdir, "fake-bin")
      log_path = File.join(tmpdir, "outdated-commands.log")
      output_path = File.join(tmpdir, "outdated-output.log")
      FileUtils.mkdir_p(bin_dir)
      %w[mise brew].each { |command| write_command_stub(bin_dir, command) }

      brew_json = '{"formulae":[{"name":"duti","installed_versions":["1.0"],"current_version":"1.1"}],"casks":[{"token":"cursor","installed_versions":["2.0"],"current_version":"2.1"}]}'
      mise_json = '{"ruby":{"current":"4.0.5","latest":"4.0.6"}}'
      env = {
        "DOTF_FORCE_NON_DEBIAN" => "true",
        "DOTF_MANAGED_BREW_FORMULAE" => "duti",
        "DOTF_MANAGED_BREW_CASKS" => "cursor",
        "DOTF_BREW_OUTDATED_JSON" => brew_json,
        "DOTF_MISE_OUTDATED_JSON" => mise_json,
        "DOTF_UPGRADE_LOG" => log_path,
        "PATH" => "#{bin_dir}:/usr/bin:/bin"
      }

      clean_homebrew_env = {"HOMEBREW_AUTO_UPDATE_SECS" => nil, "HOMEBREW_NO_AUTO_UPDATE" => nil}
      assert system(clean_homebrew_env.merge(env), "bash", script_path, "outdated", out: output_path)

      prompt_paths = Dir.glob(File.join(tmpdir, "tmp", "pi-upgrade-prompt-*.md"))
      assert_equal 1, prompt_paths.size
      assert_includes File.read(prompt_paths.first), "Update the pinned package versions"

      assert_equal [
        "brew shellenv bash", "mise activate bash", "mise outdated --json",
        "HOMEBREW_AUTO_UPDATE_SECS=604800 brew update-if-needed",
        "HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --json=v2"
      ], File.readlines(log_path, chomp: true)
      output = File.read(output_path)
      assert_includes output, "ruby\t4.0.5\t4.0.6"
      assert_includes output, "brew\tduti\t1.0\t1.1"
      assert_includes output, "brew cask\tcursor\t2.0\t2.1"
      assert_includes output, "You can run: pi"
    end
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

      lock_dir = File.join(tmpdir, "dotf.lock")
      with_env(env.merge("DOTF_UPGRADE_LOG" => log_path, "DOTF_LOCK_DIR" => lock_dir, "PATH" => "#{bin_dir}:/usr/bin:/bin")) do
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
    assert_match(/\Aruby -r \.\/lib\/dotfiles\.rb -e Dotfiles::MigrationRunner\.new\('.+'\)\.run_if_existing_machine\z/, commands[2])
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
      export DOTF_LOCK_DIR=#{Shellwords.escape(File.join(File.dirname(escaped_log), "dotf.lock"))}
      mise() { printf 'mise %s\\n' "$*" >> #{escaped_log}; }
      ruby() { printf 'ruby %s\\n' "$*" >> #{escaped_log}; }
      cmd_run
    BASH
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
