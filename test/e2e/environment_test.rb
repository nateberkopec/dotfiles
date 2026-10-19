require_relative "e2e_helper"
require_relative "../../lib/dotfiles/timed_process"

class EnvironmentTest < Minitest::Test
  def test_fish_is_the_admin_login_shell
    skip "non-admin users cannot change their login shell without sudo" unless E2E.admin?

    shell = E2E.fish!("dscl . -read /Users/(id -un) UserShell").split.last
    assert_equal "fish", File.basename(shell)
  end

  def test_fish_starts_without_errors
    _stdout, stderr, status = E2E.fish("true")
    assert status.success?
    assert_empty stderr
  end

  def test_mise_is_self_managed
    expected = File.join(E2E.home, ".local", "bin", "mise")
    assert_equal expected, E2E.fish!("command -v mise").strip
    assert_equal expected, E2E.fish!("cd ~/.dotfiles; mise exec -- /bin/sh -c 'command -v mise'").strip
  end

  def test_every_mise_tool_is_installed_at_its_pinned_version
    tools = JSON.parse(E2E.fish!("cd ~; mise ls --current --json"))
    wrong = tools.flat_map do |name, versions|
      versions.reject { |tool| tool["installed"] && tool["version"] == tool["requested_version"] }
        .map { |tool| "#{name} #{tool["requested_version"]} (installed: #{tool["installed"]}, version: #{tool["version"]})" }
    end
    assert_empty wrong
  end

  def test_mise_restores_the_aube_shim_directory_without_shell_activation
    output, status = Dotfiles::TimedProcess.new([
      {"AUBE_SHIM_DIR" => nil},
      File.join(E2E.home, ".local", "bin", "mise"), "-C", E2E.home, "exec", "node", "--", "/bin/sh", "-c", <<~SH
        test "$AUBE_SHIM_DIR" = "$HOME/.local/share/aube/shims" || exit 42
        PATH="$AUBE_SHIM_DIR:$PATH" exec "$AUBE_SHIM_DIR/node" -e 'console.log("node-ok")'
      SH
    ], timeout: 10, stream: false).run
    assert_equal 0, status, "Node shim failed (#{status}): #{output}"
    assert_equal "node-ok\n", output
  end

  def test_gui_apps_inherit_the_aube_shim_directory
    expected = File.join(E2E.home, ".local", "share", "aube", "shims")
    plist = File.join(E2E.home, "Library", "LaunchAgents", "dev.mise.aube-gui-environment.plist")
    output, stderr, status = Open3.capture3("/usr/bin/plutil", "-convert", "json", "-o", "-", plist)
    assert status.success?, stderr
    agent = JSON.parse(output)
    assert_equal true, agent.fetch("RunAtLoad")
    refute agent.fetch("KeepAlive", false)
    assert_equal ["/bin/sh", "-p", "-c", 'exec /bin/launchctl setenv AUBE_SHIM_DIR "$HOME/.local/share/aube/shims"'], agent.fetch("ProgramArguments")
    service = E2E.fish!("/bin/launchctl print gui/(id -u)/dev.mise.aube-gui-environment")
    assert_equal "not running", service[/^\s*state = (.+)$/, 1]
    assert_operator service[/^\s*runs = (\d+)$/, 1].to_i, :>, 0
    assert_equal "0", service[/^\s*last exit code = (\d+)$/, 1]
    domain = E2E.fish!("/bin/launchctl print gui/(id -u)")
    assert_equal expected, domain[/^\s*AUBE_SHIM_DIR => (.+)$/, 1]
  end

  def test_pi_packages_are_installed
    settings = JSON.parse(File.read(File.join(E2E.home, ".pi", "agent", "settings.json")))
    expected = settings.fetch("packages").map { |package| package.is_a?(Hash) ? package.fetch("source") : package }
    listed = E2E.fish!("pi list").lines.filter_map { |line| line.strip[/\A(\S+)/, 1] }
    assert_empty expected - listed
  end
end
