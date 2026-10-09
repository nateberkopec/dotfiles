require_relative "e2e_helper"

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
    assert_equal File.join(E2E.home, ".local", "bin", "mise"), E2E.fish!("command -v mise").strip
  end

  def test_every_mise_tool_is_installed_at_its_pinned_version
    tools = JSON.parse(E2E.fish!("cd ~; mise ls --current --json"))
    wrong = tools.flat_map do |name, versions|
      versions.reject { |tool| tool["installed"] && tool["version"] == tool["requested_version"] }
        .map { |tool| "#{name} #{tool["requested_version"]} (installed: #{tool["installed"]}, version: #{tool["version"]})" }
    end
    assert_empty wrong
  end

  def test_pi_packages_are_installed
    settings = JSON.parse(File.read(File.join(E2E.home, ".pi", "agent", "settings.json")))
    expected = settings.fetch("packages").map { |package| package.is_a?(Hash) ? package.fetch("source") : package }
    listed = E2E.fish!("pi list").lines.filter_map { |line| line.strip[/\A(\S+)/, 1] }
    assert_empty expected - listed
  end
end
