require "test_helper"
require "open3"

# standard:disable Dotfiles/BanFileSystemClasses
class DotfNoninteractiveTest < Minitest::Test
  def test_noninteractive_defers_privileged_work_and_preserves_existing_markers
    %w[1 true].each { |mode| assert_partial_run(mode, existing: true) }
  end

  def test_noninteractive_does_not_create_a_full_run_marker
    %w[1 true].each { |mode| assert_partial_run(mode, existing: false) }
  end

  def test_run_rejects_arguments_before_bootstrap
    with_dotf_script do |_dir, script, _logs|
      output, status = Open3.capture2e("bash", script, "run", "unexpected")
      refute status.success?
      assert_includes output, "Usage: dotf run"
    end
  end

  def test_explicit_migrations_are_also_deferred
    with_dotf_script do |dir, script, _logs|
      stub_bin = File.join(dir, "stub-bin")
      FileUtils.mkdir_p(stub_bin)
      File.write(File.join(stub_bin, "sudo"), "#!/bin/sh\nexit 1\n")
      FileUtils.chmod("+x", File.join(stub_bin, "sudo"))
      env = {"NONINTERACTIVE" => "1", "PATH" => "#{stub_bin}:#{ENV.fetch("PATH")}"}
      output, status = Open3.capture2e(env, "bash", script, "migrate")
      assert status.success?, output
      assert_includes output, "Migrations deferred"
    end
  end

  private

  def assert_partial_run(mode, existing:)
    with_dotf_script do |dir, script, _logs|
      File.write(File.join(dir, "bin", "bootstrap"), "#!/bin/bash\n[ -n \"$NONINTERACTIVE\" ]\n")
      FileUtils.chmod("+x", File.join(dir, "bin", "bootstrap"))
      state = File.join(dir, "state", "dotfiles")
      if existing
        FileUtils.mkdir_p(state)
        File.write(File.join(state, "last-run-sha"), "previous\n")
        File.write(File.join(state, "needs-run"), "dotf run\n")
      end
      command = <<~BASH
        source #{Shellwords.escape(script)}
        export HOME=#{Shellwords.escape(dir)} XDG_STATE_HOME=#{Shellwords.escape(File.join(dir, "state"))}
        export DOTF_LOCK_DIR=#{Shellwords.escape(File.join(dir, "lock"))}
        ensure_homebrew_env() { :; }
        ensure_mise_env() { :; }
        user_has_admin_rights() { return 0; }
        sudo() { return 1; }
        is_debian() { return 1; }
        mise() { echo "mise $*"; }
        ruby() { echo "ruby $*"; }
        git() { echo new-sha; }
        main run
      BASH
      output, status = Open3.capture2e({"DEBUG" => "true", "NONINTERACTIVE" => mode, "CI" => nil}, "bash", "-c", command)

      assert status.success?, output
      assert_includes output, "--skip packages"
      refute_includes output, "MigrationRunner"
      assert_includes output, "Dotfiles::Runner"
      assert_includes output, "privileged work"
      if existing
        assert_equal "previous\n", File.read(File.join(state, "last-run-sha"))
        assert File.exist?(File.join(state, "needs-run"))
      else
        refute File.exist?(File.join(state, "last-run-sha"))
      end
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
