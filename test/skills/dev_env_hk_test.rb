# standard:disable Dotfiles/BanFileSystemClasses -- black-box checker tests require temporary files
require_relative "../test_helper"
require "fileutils"
require "open3"
require "tmpdir"

class DevEnvHkTest < Minitest::Test
  CHECK = File.expand_path("../../files/home/.claude/skills/dev-env-setup/scripts/check-dev-env.fish", __dir__)
  GLOBAL_CONFIG = File.expand_path("../../files/home/.config/hk/config.pkl", __dir__)
  SCHEMA = 'amends "package://github.com/jdx/hk/releases/download/v2.0.1/hk@2.0.1#/Config.pkl"'

  def setup
    skip "fish and hk are required for checker tests" unless commands_available?
  end

  def test_minimal_project_inherits_global_lint_and_test_steps
    output = run_checker(SCHEMA, global_config: File.read(GLOBAL_CONFIG))

    assert_report output, "PASS", "pre-commit: lint step"
    assert_report output, "PASS", "pre-commit: test step"
    refute_includes output, "pre-commit: complexity step"
  end

  def test_project_overrides_global_steps_and_adds_granular_checks
    project_config = <<~PKL
      #{SCHEMA}

      hooks {
        ["pre-commit"] {
          steps {
            ["lint"] { check = "mise run lint:standard" }
            ["complexity"] { check = "mise run lint:complexity" }
            ["test"] { check = "mise run test" }
          }
        }
      }
    PKL

    output = run_checker(project_config, global_config: File.read(GLOBAL_CONFIG))

    assert_report output, "PASS", "pre-commit: lint step"
    assert_report output, "PASS", "pre-commit: test step"
  end

  def test_reports_project_overrides_that_remove_required_steps
    global_config = File.read(GLOBAL_CONFIG)

    assert_report run_checker(config_with_empty_step("lint"), global_config: global_config), "FAIL", "pre-commit: lint step"
    assert_report run_checker(config_with_empty_step("test"), global_config: global_config), "FAIL", "pre-commit: test step"
  end

  private

  def commands_available?
    system("fish", "--version", out: File::NULL, err: File::NULL) &&
      system("hk", "--version", out: File::NULL, err: File::NULL)
  end

  def config_with_empty_step(name)
    <<~PKL
      #{SCHEMA}

      hooks {
        ["pre-commit"] {
          steps {
            ["#{name}"] {}
          }
        }
      }
    PKL
  end

  def run_checker(project_config, global_config: SCHEMA)
    Dir.mktmpdir do |dir|
      project_dir = File.join(dir, "project")
      config_dir = File.join(dir, "config")
      FileUtils.mkdir_p([project_dir, config_dir])
      File.write(File.join(project_dir, "Gemfile"), "source \"https://rubygems.org\"\n")
      File.write(File.join(project_dir, "hk.pkl"), project_config)
      File.write(File.join(config_dir, "config.pkl"), global_config)
      system("git", "-C", project_dir, "init", "--quiet")
      system("git", "-C", project_dir, "add", "Gemfile", "hk.pkl")

      env = {
        "GIT_CONFIG_GLOBAL" => File::NULL,
        "GIT_CONFIG_SYSTEM" => File::NULL,
        "HK_CONFIG_DIR" => config_dir,
        "NO_COLOR" => "1"
      }
      return Open3.capture2e(env, "fish", CHECK, project_dir).first
    end
  end

  def assert_report(output, status, label)
    assert_includes output, "  #{status}  #{label}"
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
