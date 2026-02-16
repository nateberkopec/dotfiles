require "test_helper"

class SyncHomeDirectoryStepTest < StepTestCase
  step_class Dotfiles::Step::SyncHomeDirectoryStep

  def test_run_syncs_regular_files
    stub_source_file(".config/test.conf", "content")

    step.run

    assert_command_run(:cp, source_path(".config/test.conf"), home_path(".config/test.conf"))
  end

  def test_run_syncs_symlinks
    stub_source_symlink(".codex/skills", "../.claude/skills")

    step.run

    assert_command_run(:create_symlink, "../.claude/skills", home_path(".codex/skills"))
  end

  def test_run_replaces_existing_file_with_symlink
    stub_codex_skills_symlink
    @fake_system.stub_file_content(home_path(".codex/skills"), "old content")
    step.run
    assert_command_run(:rm_rf, home_path(".codex/skills"))
    assert_command_run(:create_symlink, "../.claude/skills", home_path(".codex/skills"))
  end

  def test_run_skips_symlink_already_correct
    stub_codex_skills_symlink
    stub_matching_home_symlink
    step.run
    refute_command_run(:rm_rf, home_path(".codex/skills"))
    refute_command_run(:create_symlink, "../.claude/skills", home_path(".codex/skills"))
  end

  def test_complete_when_symlinks_in_sync
    stub_source_symlink(".codex/skills", "../.claude/skills")
    @fake_system.stub_symlink(home_path(".codex/skills"), "../.claude/skills")

    assert_complete
  end

  def test_incomplete_when_symlink_missing
    stub_source_symlink(".codex/skills", "../.claude/skills")

    assert_incomplete
  end

  def test_incomplete_when_symlink_target_differs
    stub_source_symlink(".codex/skills", "../.claude/skills")
    @fake_system.stub_symlink(home_path(".codex/skills"), "wrong/target")

    assert_incomplete
  end

  def test_incomplete_when_symlink_is_regular_file
    stub_source_symlink(".codex/skills", "../.claude/skills")
    @fake_system.stub_file_content(home_path(".codex/skills"), "regular file content")

    assert_incomplete
  end

  def test_should_run_when_symlink_out_of_sync
    stub_source_symlink(".codex/skills", "../.claude/skills")

    assert_should_run
  end

  def test_should_not_run_when_symlink_in_sync
    stub_source_symlink(".codex/skills", "../.claude/skills")
    @fake_system.stub_symlink(home_path(".codex/skills"), "../.claude/skills")

    refute_should_run
  end

  def test_should_not_run_when_only_ignored_file_differs
    stub_source_file(".config/fish/fish_variables", "repo content")

    refute_should_run
    assert_complete
  end

  def test_run_prefers_platform_specific_file_over_shared_file
    @fake_system.stub_macos
    stub_source_file(".config/ghostty/config.platform", "font-size = 18")
    stub_source_file(".config/ghostty/config.platform", "font-size = 16", root: "home.macos")

    step.run

    assert_command_run(
      :cp,
      source_path(".config/ghostty/config.platform", root: "home.macos"),
      home_path(".config/ghostty/config.platform")
    )
    refute_command_run(
      :cp,
      source_path(".config/ghostty/config.platform", root: "home"),
      home_path(".config/ghostty/config.platform")
    )
  end

  def test_should_not_run_when_platform_specific_file_is_in_sync
    @fake_system.stub_macos
    stub_source_file(".config/ghostty/config.platform", "font-size = 18")
    stub_source_file(".config/ghostty/config.platform", "font-size = 16", root: "home.macos")
    @fake_system.stub_file_content(home_path(".config/ghostty/config.platform"), "font-size = 16")

    refute_should_run
    assert_complete
  end

  def test_run_prefers_host_specific_file_over_platform_file
    @fake_system.stub_macos
    @fake_system.stub_hostname("workspaces")
    stub_source_file(".config/ghostty/config.platform", "font-size = 18")
    stub_source_file(".config/ghostty/config.platform", "font-size = 16", root: "home.macos")
    stub_source_file(".config/ghostty/config.platform", "font-size = 12", root: "home.hosts/workspaces")

    step.run

    assert_command_run(
      :cp,
      source_path(".config/ghostty/config.platform", root: "home.hosts/workspaces"),
      home_path(".config/ghostty/config.platform")
    )
    refute_command_run(
      :cp,
      source_path(".config/ghostty/config.platform", root: "home.macos"),
      home_path(".config/ghostty/config.platform")
    )
  end

  private

  def source_path(relative, root: "home")
    File.join(@dotfiles_dir, "files", root, relative)
  end

  def home_path(relative)
    File.join(@home, relative)
  end

  def stub_source_file(relative, content, root: "home")
    path = source_path(relative, root: root)
    @fake_system.mkdir_p(File.dirname(path))
    @fake_system.stub_file_content(path, content)
  end

  def stub_source_symlink(relative, target)
    path = source_path(relative)
    @fake_system.mkdir_p(File.dirname(path))
    @fake_system.stub_symlink(path, target)
  end

  def stub_codex_skills_symlink
    stub_source_symlink(".codex/skills", "../.claude/skills")
  end

  def stub_matching_home_symlink
    @fake_system.stub_symlink(home_path(".codex/skills"), "../.claude/skills")
  end
end
