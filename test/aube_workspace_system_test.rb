require "test_helper"
require "tmpdir"
require "toml-rb"
require_relative "../lib/dotfiles/timed_process"

class AubeWorkspaceSystemTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir("aube-workspace")
    @bin = File.expand_path("../files/home/.local/bin", __dir__)
    @env = {"BASH_ENV" => "", "AUBE_SHIM_DIR" => File.join(@directory, "aube/shims")}
    inherited_path = ENV.fetch("PATH").split(File::PATH_SEPARATOR) - [ENV["AUBE_SHIM_DIR"], File.join(ENV.fetch("HOME"), ".local/share/aube/shims")]
    @env["PATH"] = [@env.fetch("AUBE_SHIM_DIR"), @bin, *inherited_path].join(File::PATH_SEPARATOR)
    @env["MISE_GLOBAL_CONFIG_FILE"] = File.join(@directory, "config.toml")
    tools = TomlRB.load_file(File.expand_path("../.mise.toml", __dir__)).fetch("tools").slice("node", "github:aubepkg/aube")
    File.write(@env.fetch("MISE_GLOBAL_CONFIG_FILE"), TomlRB.dump({"tools" => tools, "env" => {"_" => {"path" => [@bin]}, "AUBE_SHIM_DIR" => @env.fetch("AUBE_SHIM_DIR")}}))
    output, status = run_command("mise", "which", "aube")
    assert_equal 0, status, output
    @aube = output.strip
    output, status = run_command("env", "XDG_DATA_HOME=#{@directory}", @aube, "activate", "bash")
    assert_equal 0, status, output
    FileUtils.mkdir_p(File.join(@directory, "packages/child"))
    write_json("package.json", {name: "root", private: true, workspaces: ["packages/child"], scripts: {build: "sh root.sh", echo: "printf '%s\\n'"}})
    write_json("packages/child/package.json", {name: "@test/child", version: "1.0.0", scripts: {build: "printf 'CHILD_BUILT\\n'"}})
    File.write(File.join(@directory, "root.sh"), <<~SH)
      printf 'ROOT_RAN\\n'
      if [ "${ROOT_RUNS:-0}" -ge 2 ]; then exit 73; fi
      export ROOT_RUNS=$((${ROOT_RUNS:-0} + 1))
      exec npm run build --workspaces --if-present "$@"
    SH
  end

  def teardown
    FileUtils.remove_entry(@directory) if @directory
  end

  def test_workspace_options_are_refused_before_running_the_root_script
    [
      ["--workspace=@test/child"], ["--workspace", "@test/child"],
      ["-w", "@test/child"], ["-w@test/child"],
      ["--workspaces", "--if-present"], ["--workspaces=true"]
    ].each do |options|
      output, status = run_command("npm", "run", "build", *options)
      assert_equal 64, status, output
      assert_includes output, "aube --filter"
      refute_includes output, "ROOT_RAN"
    end
  end

  def test_nested_npm_workspace_run_stops_after_one_root_execution
    output, status = run_command("aube", "run", "build")
    assert_equal 64, status, output
    assert_equal 1, output.lines.count { |line| line.strip == "ROOT_RAN" }, output
  end

  def test_native_aube_workspace_selection_still_runs_the_child
    [["--filter", "@test/child"], ["-r"]].each do |options|
      output, status = run_command("aube", *options, "run", "build")
      assert_equal 0, status, output
      assert_includes output, "CHILD_BUILT"
      refute_includes output, "ROOT_RAN"
    end
  end

  def test_script_arguments_after_separator_are_preserved
    output, status = run_command("npm", "run", "echo", "--", "--workspaces")
    assert_equal 0, status, output
    assert_includes output.lines.map(&:strip), "--workspaces"
  end

  def test_install_still_uses_aube_without_native_npm_fallback
    output, status = run_command("npm", "install", "--offline", "--ignore-scripts")
    assert_equal 0, status, output
    assert_match(/\baube \d+\./, output.gsub(/\e\[[0-9;]*m/, ""))
  end

  def test_launcher_uses_the_host_tool_when_a_project_pins_an_uninstalled_version
    File.write(File.join(@directory, ".mise.toml"), "[tools]\n\"github:aubepkg/aube\" = \"0.0.0\"\n")
    @env["MISE_TRUSTED_CONFIG_PATHS"] = @directory
    output, status = run_command("aube", "--version")
    assert_equal 0, status, output
  end

  def test_launcher_finds_aube_when_a_caller_overrides_home
    @env["HOME"] = Dir.mktmpdir("fake-home", @directory)
    output, status = run_command("npm", "--version")
    assert_equal 0, status, output
    refute_includes output, "not a mise bin"
  end

  def test_mise_exec_preserves_the_guard
    output, status = run_command("mise", "exec", "--", File.join(@env.fetch("AUBE_SHIM_DIR"), "npm"), "run", "build", "--workspace=@test/child")
    assert_equal 64, status, output
    refute_includes output, "ROOT_RAN"
  end

  private

  def run_command(*argv)
    command = [@env, "/bin/sh", "-c", 'cd "$1" && shift && exec "$@"', "aube-test", @directory, *argv]
    Dotfiles::TimedProcess.new(command, timeout: 10, stream: false).run
  end

  def write_json(path, data)
    File.write(File.join(@directory, path), JSON.generate(data))
  end
end
