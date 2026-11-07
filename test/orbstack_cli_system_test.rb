require "test_helper"
require "tmpdir"
require "toml-rb"

class OrbStackCliSystemTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir("orbstack-cli")
    @mise = ENV.fetch("PATH").split(File::PATH_SEPARATOR).map { |path| File.join(path, "mise") }.find { |path| File.executable?(path) }
    @config = File.join(@directory, "config.toml")
    @data = File.join(@directory, "data")
    @tool = TomlRB.load_file(File.expand_path("../files/home/.config/mise/config.toml", __dir__)).fetch("tools").fetch("aqua:dotfiles/orbstack").except("os", "arch")
    @install = File.join(@data, "installs/aqua-dotfiles-orbstack", @tool.fetch("version"))
    @active = File.join(@directory, ".orbstack/bin")
    FileUtils.mkdir_p([@install, @active])
    File.write(@config, TomlRB.dump({"tools" => {"aqua:dotfiles/orbstack" => @tool}}))
    @env = {"HOME" => @directory, "PATH" => "/usr/bin:/bin", "MISE_DATA_DIR" => @data,
            "MISE_CONFIG_DIR" => File.join(@directory, "config"), "MISE_CACHE_DIR" => File.join(@directory, "cache"),
            "MISE_STATE_DIR" => File.join(@directory, "state"), "MISE_GLOBAL_CONFIG_FILE" => @config,
            "MISE_TRUSTED_CONFIG_PATHS" => @directory, "MISE_OFFLINE" => "1", "BASH_ENV" => ""}
    %w[orb orbctl].each { |cli| write_cli(File.join(@active, cli), "active-2.2.4") }
  end

  def teardown
    FileUtils.remove_entry(@directory) if @directory
  end

  def test_mise_keeps_using_the_active_app_before_and_after_a_coordinated_upgrade
    converge
    assert_active_version("active-2.2.4")
    %w[orb orbctl].each { |cli| write_cli(File.join(@active, cli), "active-2.2.5") }
    assert_active_version("active-2.2.5")
    File.unlink(File.join(@install, ".mise-bins/orb"))
    converge
    assert_active_version("active-2.2.5")
  end

  private

  def converge
    output, status = run_mise("install", "aqua:dotfiles/orbstack")
    assert status.success?, output
    %w[orb orbctl].each do |cli|
      assert_equal File.join(@active, cli), File.readlink(File.join(@install, ".mise-bins", cli))
    end
  end

  def assert_active_version(version)
    %w[orb orbctl].each do |cli|
      output, status = run_mise("exec", "--", cli)
      assert status.success?, output
      assert_equal version, output.strip
    end
  end

  def run_mise(*args)
    Open3.capture2e(@env, @mise, *args, chdir: @directory, unsetenv_others: true)
  end

  def write_cli(path, output)
    File.write(path, "#!/bin/sh\nprintf '%s\\n' '#{output}'\n")
    File.chmod(0o755, path)
  end
end
