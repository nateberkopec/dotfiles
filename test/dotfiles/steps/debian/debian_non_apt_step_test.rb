require "test_helper"

class DebianNonAptStepTest < StepTestCase
  class DummyNonAptStep < Dotfiles::Step
    include Dotfiles::Step::DebianNonAptStep

    private

    def package_name
      "dummy"
    end

    def install
      execute("install dummy")
    end
  end

  step_class DummyNonAptStep

  def setup
    super
    @fake_system.stub_debian
  end

  def test_should_not_run_by_default
    stub_dummy_missing

    refute_should_run
  end

  def test_complete_by_default
    stub_dummy_missing

    assert_complete
  end

  def test_should_run_when_configured_and_missing
    stub_dummy_missing
    write_config("config", "debian_non_apt_packages" => ["dummy"])

    assert_should_run
  end

  def test_run_installs_when_configured
    stub_dummy_missing
    write_config("config", "debian_non_apt_packages" => ["dummy"])

    step.run

    assert_executed("install dummy")
  end

  def test_run_skips_when_not_configured
    stub_dummy_missing

    step.run

    refute_executed("install dummy")
  end

  def test_incomplete_when_configured_and_missing
    stub_dummy_missing
    write_config("config", "debian_non_apt_packages" => ["dummy"])

    refute step.complete?
    assert_includes step.errors, "Non-APT package not installed: dummy"
  end

  def test_complete_when_installed
    stub_dummy_installed
    write_config("config", "debian_non_apt_packages" => ["dummy"])

    assert_complete
  end

  private

  def stub_dummy_missing
    @fake_system.stub_command("command -v dummy >/dev/null 2>&1", "", exit_status: 1)
  end

  def stub_dummy_installed
    @fake_system.stub_command("command -v dummy >/dev/null 2>&1", "", exit_status: 0)
  end
end
