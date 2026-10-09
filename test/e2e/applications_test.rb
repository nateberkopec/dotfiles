require_relative "e2e_helper"

class ApplicationsTest < Minitest::Test
  def test_every_cask_app_is_installed_and_signed
    casks = E2E.config.fetch("brew_casks")
    info = JSON.parse(E2E.fish!("brew info --cask --json=v2 #{casks.join(" ")}")).fetch("casks")
    problems = info.flat_map { |cask| cask_apps(cask) }.filter_map { |app| problem(app) }
    assert_empty problems
  end

  def test_non_admin_uses_only_its_home
    skip "admin machines install machine-wide" if E2E.admin?

    assert_equal File.join(E2E.home, ".homebrew"), E2E.fish!("brew --prefix").strip
    refute File.exist?("/opt/homebrew")
    outside = E2E.fish!("find /Applications /Library /opt /usr/local -maxdepth 4 -user (id -un) -print 2>/dev/null; true")
    assert_empty outside.lines
  end

  private

  def cask_apps(cask)
    cask.fetch("artifacts").filter_map { |artifact| artifact["app"]&.first }.map do |app|
      File.join(app_dir, app.is_a?(Hash) ? app.fetch("target") : app)
    end
  end

  def app_dir
    E2E.admin? ? "/Applications" : File.join(E2E.home, "Applications")
  end

  def problem(app)
    return "#{app} is missing" unless File.directory?(app)

    _stdout, stderr, status = Open3.capture3("/usr/bin/codesign", "--verify", app)
    "#{app} fails codesign: #{stderr.strip}" unless status.success?
  end
end
