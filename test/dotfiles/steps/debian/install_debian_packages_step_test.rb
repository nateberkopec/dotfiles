require "test_helper"

class InstallDebianPackagesStepTest < StepTestCase
  step_class Dotfiles::Step::InstallDebianPackagesStep

  def test_should_not_run_by_default
    refute_should_run
  end

  def test_complete_by_default
    assert_complete
  end

  def test_should_run_when_source_missing
    write_config(
      "config",
      "debian_sources" => [{"name" => "example", "line" => "deb https://example.invalid stable main"}]
    )

    assert_should_run
  end

  def test_incomplete_when_source_missing
    write_config(
      "config",
      "debian_sources" => [{"name" => "example", "line" => "deb https://example.invalid stable main"}]
    )

    assert_incomplete
  end

  def test_installs_missing_source_list
    source_line = "deb https://example.invalid stable main"
    write_config("config", "debian_sources" => [{"name" => "example", "line" => source_line}])

    step.run

    assert @fake_system.received_operation?(:write_file)
    assert @fake_system.operations.any? { |op, command, _| op == :execute && command.include?("install") }
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

  def test_skips_amd64_only_sources_in_container
    @fake_system.stub_debian
    @fake_system.stub_running_container
    write_unsupported_third_party_config

    refute_should_run
    assert_complete
    assert_empty step.warnings
  end

  def test_skips_unsupported_third_party_sources_on_github_actions
    with_env("GITHUB_ACTIONS" => "true") do
      @fake_system.stub_debian
      write_unsupported_third_party_config

      refute_should_run
      assert_complete
      assert_empty step.warnings
    end
  end

  def test_debian_ci_sources_override_disables_configured_sources
    with_env("DEBIAN_CI_SOURCES" => "") do
      @fake_system.stub_debian
      write_config(
        "config",
        "debian_sources" => [
          {"name" => "example", "line" => "deb https://example.invalid stable main"}
        ]
      )

      refute_should_run
      assert_complete
    end
  end

  def write_unsupported_third_party_config
    write_config(
      "config",
      "debian_sources" => [
        {"name" => "1password", "line" => "deb https://example.invalid stable main"},
        {"name" => "google-chrome", "line" => "deb https://example.invalid stable main"}
      ]
    )
  end
end
