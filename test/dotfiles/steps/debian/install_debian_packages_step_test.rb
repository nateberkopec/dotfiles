require "test_helper"

class InstallDebianPackagesStepTest < StepTestCase
  step_class Dotfiles::Step::InstallDebianPackagesStep

  def test_should_not_run_by_default
    refute_should_run
  end

  def test_complete_by_default
    assert_complete
  end

  def test_should_run_when_package_missing
    stub_package_missing("ripgrep")
    write_config(
      "config",
      "packages" => {
        "ripgrep" => {"debian" => "ripgrep"}
      }
    )

    assert_should_run
  end

  def test_incomplete_when_package_missing
    stub_package_missing("ripgrep")
    write_config(
      "config",
      "packages" => {
        "ripgrep" => {"debian" => "ripgrep"}
      }
    )

    assert_incomplete
  end

  def test_reports_apt_install_failure
    stub_package_missing("ripgrep")
    write_config(
      "config",
      "packages" => {
        "ripgrep" => {"debian" => "ripgrep"}
      }
    )

    @fake_system.stub_command("sudo DEBIAN_FRONTEND=noninteractive apt-get update -y", "", exit_status: 0)
    @fake_system.stub_command(
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ripgrep",
      "E: Unable to locate package ripgrep",
      exit_status: 100
    )

    step.run

    refute step.complete?
    assert_includes step.errors, "apt-get install failed (status 100): E: Unable to locate package ripgrep"
  end

  def test_docker_io_skipped_when_docker_available
    @fake_system.stub_command("command -v docker >/dev/null 2>&1", "", exit_status: 0)
    write_config(
      "config",
      "packages" => {
        "docker" => {"debian" => "docker.io"}
      }
    )

    refute_should_run
  end

  def test_source_mismatch_ignores_comment_lines
    source_line = "deb [signed-by=/usr/share/keyrings/example-archive-keyring.gpg] https://example.invalid stable main"
    write_config(
      "config",
      "debian_sources" => [
        {"name" => "example", "line" => source_line}
      ]
    )

    list_path = "/etc/apt/sources.list.d/example.list"
    @fake_system.stub_file_content(list_path, "# managed by package\n#{source_line}\n")

    assert_empty step.send(:missing_sources)
  end

  def test_skips_amd64_only_packages_and_sources_in_container
    @fake_system.stub_debian
    @fake_system.stub_running_container
    write_config(
      "config",
      "packages" => {
        "one_password" => {"debian" => "1password"},
        "chrome" => {"debian" => "google-chrome-stable"}
      },
      "debian_sources" => [
        {"name" => "1password", "line" => "deb https://example.invalid stable main"},
        {"name" => "google-chrome", "line" => "deb https://example.invalid stable main"}
      ]
    )

    refute_should_run
    assert_complete
    assert_empty step.warnings
  end

  private

  def stub_package_missing(name)
    @fake_system.stub_command("dpkg -s #{name} >/dev/null 2>&1", "", exit_status: 1)
    @fake_system.stub_command("apt-cache show #{name} >/dev/null 2>&1", "", exit_status: 0)
  end
end
