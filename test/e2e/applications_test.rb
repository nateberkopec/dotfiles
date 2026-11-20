require_relative "e2e_helper"

class ApplicationsTest < Minitest::Test
  def test_every_vendor_app_is_installed_and_signed
    apps = E2E.config.fetch("vendor_apps")
    apps = apps.reject { |app| app["admin_only"] } unless E2E.admin?
    assert_empty apps.filter_map { |app| problem(app) }
  end

  def test_non_admin_uses_only_its_home
    skip "admin machines install machine-wide" if E2E.admin?

    assert_equal File.join(E2E.home, ".homebrew"), E2E.fish!("brew --prefix").strip
    refute File.exist?("/opt/homebrew")
    outside = E2E.fish!("find /Applications /Library /opt /usr/local -maxdepth 4 -user (id -un) -print 2>/dev/null; true")
    assert_empty outside.lines
  end

  private

  def app_dir
    E2E.admin? ? "/Applications" : File.join(E2E.home, "Applications")
  end

  def problem(app)
    path = File.join(app_dir, "#{app.fetch("name")}.app")
    return "#{path} is missing" unless File.directory?(path)

    requirement = %(anchor apple generic and certificate leaf[subject.OU] = "#{app.fetch("team_id")}")
    _stdout, stderr, status = Open3.capture3("/usr/bin/codesign", "--verify", "-R=#{requirement}", path)
    "#{path} fails codesign: #{stderr.strip}" unless status.success?
  end
end
