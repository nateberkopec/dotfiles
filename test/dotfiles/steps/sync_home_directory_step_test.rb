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

  def test_run_skips_untracked_files
    stub_source_file(".config/tracked.conf", "tracked content")
    stub_source_file(".config/local.conf", "local content", tracked: false)

    step.run

    assert_command_run(:cp, source_path(".config/tracked.conf"), home_path(".config/tracked.conf"))
    refute_command_run(:cp, source_path(".config/local.conf"), home_path(".config/local.conf"))
  end

  def test_run_skips_untracked_platform_files
    @fake_system.stub_macos
    stub_source_file(".config/ghostty/tracked.platform", "tracked", root: "home.macos")
    stub_source_file(".config/ghostty/local.platform", "local", root: "home.macos", tracked: false)

    step.run

    assert_command_run(
      :cp,
      source_path(".config/ghostty/tracked.platform", root: "home.macos"),
      home_path(".config/ghostty/tracked.platform")
    )
    refute_command_run(
      :cp,
      source_path(".config/ghostty/local.platform", root: "home.macos"),
      home_path(".config/ghostty/local.platform")
    )
  end

  def test_run_skips_untracked_host_files
    @fake_system.stub_hostname("workspaces")
    stub_source_file(".config/ghostty/tracked.host", "tracked", root: "home.hosts/workspaces")
    stub_source_file(".config/ghostty/local.host", "local", root: "home.hosts/workspaces", tracked: false)

    step.run

    assert_command_run(
      :cp,
      source_path(".config/ghostty/tracked.host", root: "home.hosts/workspaces"),
      home_path(".config/ghostty/tracked.host")
    )
    refute_command_run(
      :cp,
      source_path(".config/ghostty/local.host", root: "home.hosts/workspaces"),
      home_path(".config/ghostty/local.host")
    )
  end

  def test_run_uses_committed_paths_as_the_tracking_source
    stub_source_file(".config/test.conf", "content")

    step.run

    assert_executed(tracked_paths_command("home"))
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

  def stub_source_file(relative, content, root: "home", tracked: true)
    stub_source_entry(relative, root: root, tracked: tracked, content: content)
  end

  def stub_source_symlink(relative, target, root: "home", tracked: true)
    stub_source_entry(relative, root: root, tracked: tracked, target: target)
  end

  def stub_source_entry(relative, root:, tracked:, content: nil, target: nil)
    path = source_path(relative, root: root)
    @fake_system.mkdir_p(File.dirname(path))
    target ? @fake_system.stub_symlink(path, target) : @fake_system.stub_file_content(path, content)
    stub_tracked_source(relative, root: root) if tracked
  end

  def stub_tracked_source(relative, root: "home")
    tracked_sources[root] << File.join("files", root, relative)
    @fake_system.stub_command(tracked_paths_command(root), "#{tracked_sources[root].join("\0")}\0")
  end

  def tracked_sources
    @tracked_sources ||= Hash.new { |sources, root| sources[root] = [] }
  end

  def tracked_paths_command(root)
    "git -C #{@dotfiles_dir} ls-tree -r -z --name-only HEAD -- files/#{root}"
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
