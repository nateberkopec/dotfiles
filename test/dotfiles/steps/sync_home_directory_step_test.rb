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

  def test_run_replaces_existing_agents_skills_directory_with_symlink
    stub_source_symlink(".agents/skills", "../.dotfiles/files/home/.claude/skills")
    @fake_system.mkdir_p(home_path(".agents/skills/argument-validator"))
    step.run
    assert_command_run(:rm_rf, home_path(".agents/skills"))
    assert_command_run(
      :create_symlink,
      "../.dotfiles/files/home/.claude/skills",
      home_path(".agents/skills")
    )
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

  def test_should_not_run_when_only_pi_auth_differs
    stub_source_file(".pi/agent/auth.json", "repo auth content")

    refute_should_run
    assert_complete
  end

  def test_run_removes_obsolete_reviewer_agent_override
    @fake_system.stub_file_content(home_path(".pi/agent/agents/reviewer.md"), "old reviewer override")

    step.run

    assert_command_run(:rm_rf, home_path(".pi/agent/agents/reviewer.md"))
    refute @fake_system.file_exist?(home_path(".pi/agent/agents/reviewer.md"))
  end

  def test_should_run_when_obsolete_reviewer_agent_override_exists
    @fake_system.stub_file_content(home_path(".pi/agent/agents/reviewer.md"), "old reviewer override")

    assert_should_run
    assert_incomplete
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

  def test_run_removes_user_immutable_flag_before_retrying_copy
    dest = home_path(".gem/credentials")
    stub_source_file(".gem/credentials", "stub")
    copy_attempts = stub_copy_fails_once_then_succeeds

    step.run

    assert_executed("chflags nouchg '#{dest}'", quiet: false)
    refute_executed("sudo chflags nouchg,noschg '#{dest}'", quiet: false)
    assert_equal "stub", @fake_system.filesystem[dest]
    assert_equal 2, copy_attempts.call
  end

  def test_run_falls_back_to_sudo_when_user_flag_clear_fails
    dest = home_path(".gem/credentials")
    stub_source_file(".gem/credentials", "stub")
    @fake_system.stub_command("chflags nouchg '#{dest}'", "", 1)
    copy_attempts = stub_copy_fails_once_then_succeeds

    step.run

    assert_executed("chflags nouchg '#{dest}'", quiet: false)
    assert_executed("sudo chflags nouchg,noschg '#{dest}'", quiet: false)
    assert_equal "stub", @fake_system.filesystem[dest]
    assert_equal 2, copy_attempts.call
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

  def stub_copy_fails_once_then_succeeds
    attempts = 0
    @fake_system.define_singleton_method(:cp) do |src, dest_path|
      @operations << [:cp, src, dest_path]
      attempts += 1
      raise Errno::EPERM, dest_path if attempts == 1

      @filesystem[File.expand_path(dest_path)] = @filesystem[File.expand_path(src)]
    end
    -> { attempts }
  end

  def stub_codex_skills_symlink
    stub_source_symlink(".codex/skills", "../.claude/skills")
  end

  def stub_matching_home_symlink
    @fake_system.stub_symlink(home_path(".codex/skills"), "../.claude/skills")
  end
end
