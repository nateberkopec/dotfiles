require "test_helper"
require "open3"
require "fileutils"
require "shellwords"
require "tmpdir"

class PiProfilesTest < Minitest::Test
  CONFIG = File.expand_path("../../files/home/.config/fish/config.fish", __dir__)

  def setup
    skip "Fish is not installed" unless system("fish", "--version", out: File::NULL)
  end

  def test_launchers_choose_mode_without_changing_agent_directory
    with_functions do |dir, source|
      assert_equal "usa-no-train|shared|--print hello\n", run_fish(dir, source, "pi --print hello")
      assert_equal "claude-only|shared|--print hello\n", run_fish(dir, source, "pi-claude --print hello")
      assert_equal "unrestricted|shared|--print hello\n", run_fish(dir, source, "pi-unsafe --print hello")
    end
  end

  def test_only_child_processes_inherit_the_launch_mode
    with_functions do |dir, source|
      assert_equal "claude-only|shared|--list-models\n",
        run_fish(dir, source, "pi --list-models", "PI_SUBAGENT_DEPTH" => "1", "PI_DATASAFE_MODE" => "claude-only")
      assert_equal "usa-no-train|shared|--list-models\n",
        run_fish(dir, source, "pi --list-models", "PI_SUBAGENT_DEPTH" => "0", "PI_DATASAFE_MODE" => "unrestricted")
      assert_equal "invalid|shared|--list-models\n",
        run_fish(dir, source, "pi --list-models", "PI_SUBAGENT_DEPTH" => "1", "PI_DATASAFE_MODE" => "invalid")
    end
  end

  def test_sessions_are_noninteractive_without_changing_the_parent_shell
    with_functions do |dir, source|
      File.write(File.join(dir, "bin", "pi"), "#!/bin/sh\nprintf '%s\\n' \"$NONINTERACTIVE\"\n")
      %w[pi pi-claude pi-unsafe].each do |launcher|
        assert_equal "1\nparent:unset\n", run_fish(dir, source, "#{launcher} --print hello; echo parent:(set -q NONINTERACTIVE; and echo set; or echo unset)", "NONINTERACTIVE" => nil)
      end
    end
  end

  private

  def with_functions
    Dir.mktmpdir("pi-profiles") do |dir|
      config = File.read(CONFIG)
      functions = config.split("function pi\n", 2).last.split("# Activate mise early", 2).first
      source = File.join(dir, "functions.fish")
      File.write(source, "function pi\n#{functions}")
      FileUtils.mkdir_p(File.join(dir, "bin"))
      executable = File.join(dir, "bin", "pi")
      File.write(executable, "#!/bin/sh\nprintf '%s|%s|%s\\n' \"$PI_DATASAFE_MODE\" \"$PI_CODING_AGENT_DIR\" \"$*\"\n")
      FileUtils.chmod("+x", executable)
      yield dir, source
    end
  end

  def run_fish(dir, source, command, extra = {})
    env = {"MOCK_NODE_ROOT" => dir, "PI_CODING_AGENT_DIR" => "shared"}.merge(extra)
    script = "function mise; echo $MOCK_NODE_ROOT; end; source #{Shellwords.escape(source)}; #{command}"
    output, status = Open3.capture2e(env, "fish", "--no-config", "--command", script)
    assert status.success?, output
    output
  end
end
