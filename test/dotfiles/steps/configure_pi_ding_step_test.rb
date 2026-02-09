require "test_helper"

class ConfigurePiDingStepTest < StepTestCase
  step_class Dotfiles::Step::ConfigurePiDingStep

  def test_run_creates_settings_and_enables_pi_ding
    @fake_system.stub_macos
    stub_ding_template

    step.run

    settings = JSON.parse(@fake_system.read_file(settings_path))
    assert_includes settings.fetch("packages"), "npm:pi-ding"
    assert_equal true, settings.dig("ding", "enabled")
  end

  def test_run_does_not_overwrite_existing_custom_ding_settings
    @fake_system.stub_macos
    stub_settings({
      "packages" => ["npm:pi-ding"],
      "ding" => {"enabled" => true, "player" => "mpv", "path" => "~/sounds/done.mkv"}
    })

    step.run

    settings = JSON.parse(@fake_system.read_file(settings_path))
    assert_equal "mpv", settings.dig("ding", "player")
    assert_equal "~/sounds/done.mkv", settings.dig("ding", "path")
  end

  def test_run_adds_pi_ding_without_changing_other_settings
    @fake_system.stub_macos
    stub_ding_template
    stub_settings({"defaultModel" => "gpt-5", "packages" => []})

    step.run

    settings = JSON.parse(@fake_system.read_file(settings_path))
    assert_equal "gpt-5", settings.fetch("defaultModel")
    assert_includes settings.fetch("packages"), "npm:pi-ding"
    assert_equal true, settings.dig("ding", "enabled")
  end

  def test_incomplete_if_settings_json_invalid
    @fake_system.stub_file_content(settings_path, "{ not json")

    assert_incomplete
  end

  private

  def settings_path
    File.join(@home, ".pi", "agent", "settings.json")
  end

  def ding_template_path
    File.join(@dotfiles_dir, "files", "home", ".pi", "agent", "ding.json")
  end

  def stub_ding_template
    @fake_system.mkdir_p(File.dirname(ding_template_path))
    @fake_system.stub_file_content(ding_template_path, JSON.pretty_generate({
      "enabled" => true,
      "player" => "afplay",
      "path" => "/System/Library/Sounds/Glass.aiff"
    }) + "\n")
  end

  def stub_settings(hash)
    @fake_system.mkdir_p(File.dirname(settings_path))
    @fake_system.stub_file_content(settings_path, JSON.pretty_generate(hash) + "\n")
  end
end
