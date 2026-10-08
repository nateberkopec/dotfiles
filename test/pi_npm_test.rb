require "fileutils"
require "open3"
require "test_helper"
require "tmpdir"

# standard:disable Dotfiles/BanFileSystemClasses -- black-box wrapper test requires real temporary executables
class PiNpmTest < Minitest::Test
  def test_uses_nodes_bundled_npm_instead_of_the_path_shim
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "node", "bin"))
      executable(File.join(dir, "mise"), "test \"$*\" = 'which node' || exit 2\nprintf '%s\\n' '#{dir}/node/bin/node'")
      executable(File.join(dir, "npm"), "exit 99")
      executable(File.join(dir, "node", "bin", "npm"), 'printf "%s\\n" "$@"')
      command = File.expand_path("../bin/pi-npm", __dir__)

      output, status = Open3.capture2({"PATH" => "#{dir}:/usr/bin:/bin", "BASH_ENV" => ""}, "bash", command, "install", "pi-mcp-adapter@4.0.0", "--legacy-peer-deps")

      assert status.success?
      assert_equal "install\npi-mcp-adapter@4.0.0\n--legacy-peer-deps\n", output
    end
  end

  private

  def executable(path, body)
    File.write(path, "#!/bin/sh\n#{body}\n")
    File.chmod(0o755, path)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
