require "fileutils"
require "open3"
require "test_helper"
require "tmpdir"

# standard:disable Dotfiles/BanFileSystemClasses -- black-box wrapper test requires real temporary executables
class PiNpmTest < Minitest::Test
  def test_translates_peer_flags_without_bypassing_aube_or_its_scanner
    with_tools('printf "%s\\n" "$AUBE_SECURITY_SCANNER" >&2; printf "%s\\n" "$@"') do |env, command|
      output, error, status = Open3.capture3(env, "bash", command, "install", "pi-mcp-adapter@4.0.0", "--prefix", "/isolated/npm", "--legacy-peer-deps")

      assert status.success?
      assert_equal "__aube-shim\nnpm\ninstall\npi-mcp-adapter@4.0.0\n--prefix\n/isolated/npm\n--config.auto-install-peers=false\n--config.strict-peer-dependencies=false\n", output
      assert_equal "/scanner-must-remain\n", error
    end
  end

  def test_settings_identify_the_wrapper_as_npm_for_pis_git_installs
    path = File.expand_path("../files/home/.pi/agent/settings.json", __dir__)
    assert_equal "npm", JSON.parse(File.read(path)).fetch("npmCommand").last
  end

  def test_git_dependency_installs_omit_development_packages
    with_tools('printf "%s\\n" "$@"') do |env, command|
      output, _, status = Open3.capture3(env, "bash", command, "install", "--omit=dev", "--legacy-peer-deps")

      assert status.success?
      assert_equal "__aube-shim\nnpm\ninstall\n--prod\n--config.auto-install-peers=false\n--config.strict-peer-dependencies=false\n", output
    end
  end

  def test_aube_rejection_is_propagated_without_an_npm_fallback
    with_tools("exit 42") do |env, command|
      _, _, status = Open3.capture3(env, "bash", command, "install", "rejected-package")

      assert_equal 42, status.exitstatus
    end
  end

  private

  def with_tools(aube)
    Dir.mktmpdir do |dir|
      executable(File.join(dir, "mise"), "test \"$1 $2 $3 $4\" = 'exec node -- aube' || exit 2\nshift 4\nexec aube \"$@\"")
      executable(File.join(dir, "npm"), "exit 99")
      executable(File.join(dir, "aube"), aube)
      env = {"PATH" => "#{dir}:/usr/bin:/bin", "BASH_ENV" => "", "AUBE_SECURITY_SCANNER" => "/scanner-must-remain"}
      yield env, File.expand_path("../files/home/.pi/agent/pi-npm.sh", __dir__)
    end
  end

  def executable(path, body)
    File.write(path, "#!/bin/sh\n#{body}\n")
    File.chmod(0o755, path)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
