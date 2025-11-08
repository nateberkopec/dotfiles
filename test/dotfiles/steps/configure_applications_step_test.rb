require "test_helper"

class ConfigureApplicationsStepTest < StepTestCase
  step_class Dotfiles::Step::ConfigureApplicationsStep

  def setup
    super
    stub_default_paths(step)
  end

  def test_complete_when_all_files_match
    seed_files(repo: "same", home: "same")
    assert_complete
  end

  def test_incomplete_when_any_file_differs
    seed_files(repo: "same", home: "different")
    assert_incomplete
  end

  def test_incomplete_when_files_missing
    assert_incomplete
  end

  def test_update_copies_changed_files
    seed_files(repo: "old", home: "new")
    step.update

    file_pairs.each_value do |paths|
      assert_equal "new", @fake_system.read_file(paths[:repo])
    end
  end

  def test_update_skips_matching_files
    seed_files(repo: "same", home: "same")
    step.update
    refute_command_run(:cp)
  end

  def test_update_handles_missing_files
    step.update
    refute_command_run(:cp)
  end

  private

  def step_overrides
    {dotfiles_dir: @fixtures_dir}
  end

  def file_pairs
    @file_pairs ||= {
      ghostty: {
        home: File.join(@home, "Library/Application Support/com.mitchellh.ghostty/config"),
        repo: File.join(@fixtures_dir, "files/ghostty/config")
      },
      aerospace: {
        home: File.join(@home, ".aerospace.toml"),
        repo: File.join(@fixtures_dir, "files/aerospace/.aerospace.toml")
      },
      git: {
        home: File.join(@home, ".gitconfig"),
        repo: File.join(@fixtures_dir, "files/git/.gitconfig")
      },
      hushlogin: {
        home: File.join(@home, ".hushlogin"),
        repo: File.join(@fixtures_dir, "files/.hushlogin")
      }
    }
  end

  def seed_files(repo:, home:)
    file_pairs.each_value do |paths|
      @fake_system.stub_file_content(paths[:repo], repo)
      @fake_system.stub_file_content(paths[:home], home)
    end
  end
end
