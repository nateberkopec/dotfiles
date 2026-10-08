require "test_helper"
require "open3"
require "rbconfig"

class DotfFileDescriptorSystemTest < Minitest::Test
  def test_fresh_machine_limit_is_raised_before_bootstrap_and_mise
    assert_run_limits(soft: 256, hard: "unlimited", expected: 4000)
  end

  def test_higher_inherited_limit_is_preserved
    assert_run_limits(soft: 8192, hard: 8192, expected: 8192)
  end

  def test_lower_hard_limit_caps_the_target
    assert_run_limits(soft: 256, hard: 1024, expected: 1024)
  end

  def test_unraisable_limit_does_not_abort_setup
    assert_run_limits(soft: 256, hard: 256, expected: 256)
  end

  private

  def assert_run_limits(soft:, hard:, expected:)
    descriptor_count = [512, expected - 32].min
    with_dotf_script do |dir, script, _logs|
      command = <<~BASH
        source #{Shellwords.escape(script)}
        export HOME=#{Shellwords.escape(dir)}
        export DOTF_LOCK_DIR=#{Shellwords.escape(File.join(dir, "lock"))}
        printf '#!/bin/bash\nprintf "bootstrap limit: %%s\\n" "$(ulimit -Sn)"\n' > "$SCRIPT_DIR/bootstrap"
        chmod +x "$SCRIPT_DIR/bootstrap"
        ensure_homebrew_env() { :; }
        ensure_mise_env() { :; }
        run_project_dependencies() { :; }
        run_mise_prune() { :; }
        mise() {
          printf 'mise limit: %s\n' "$(ulimit -Sn)"
          #{Shellwords.escape(RbConfig.ruby)} -e 'files = Array.new(#{descriptor_count}) { File.open("/dev/null") }; puts "opened #{descriptor_count} descriptors"'
        }
        ruby() { :; }
        ulimit -Sn #{soft}
        if [ "#{hard}" != "unlimited" ]; then
          ulimit -Hn #{hard}
        fi
        main run
      BASH
      output, status = Open3.capture2e({"DEBUG" => "true", "NONINTERACTIVE" => "1"}, "/bin/bash", "-c", command)
      assert status.success?, output
      assert_includes output, "bootstrap limit: #{expected}"
      assert_includes output, "mise limit: #{expected}"
      assert_includes output, "opened #{descriptor_count} descriptors"
    end
  end
end
