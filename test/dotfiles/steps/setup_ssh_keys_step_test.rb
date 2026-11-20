require "test_helper"

class SetupSSHKeysStepTest < Minitest::Test
  def test_idempotency_does_not_duplicate_config
    step = create_step(Dotfiles::Step::SetupSSHKeysStep)

    # First run: create config
    step.run
    assert step.complete?

    # Capture state after first run
    first_run_content = @fake_system.read_file(Dotfiles::Step::SetupSSHKeysStep::SSH_CONFIG_PATH)
    @fake_system.operations.dup

    # Second run: should be a no-op
    step2 = create_step(Dotfiles::Step::SetupSSHKeysStep)
    step2.run

    # Verify no duplicate writes
    second_run_content = @fake_system.read_file(Dotfiles::Step::SetupSSHKeysStep::SSH_CONFIG_PATH)
    assert_equal first_run_content, second_run_content

    # Should not have written file again
    write_operations = @fake_system.operations.select { |(op, *_)| op == :write_file }
    assert_equal 1, write_operations.length
  end

  def test_creates_ssh_config_when_missing
    step = create_step(Dotfiles::Step::SetupSSHKeysStep)

    refute step.complete?
    step.run
    assert step.complete?

    config = @fake_system.read_file(Dotfiles::Step::SetupSSHKeysStep::SSH_CONFIG_PATH)
    assert_includes config, "IdentityAgent"
    assert_includes config, "1password"
  end

  def test_appends_to_existing_ssh_config
    ssh_config_path = Dotfiles::Step::SetupSSHKeysStep::SSH_CONFIG_PATH
    original = "Host github.com\n  User git\n\nHost sfactory server-1 server-2\n  IdentityFile ~/.ssh/sfactory_ed25519\n  IdentitiesOnly yes\n  IdentityAgent none\n"
    @fake_system.stub_file_content(ssh_config_path, original)
    socket = File.join(@home, "Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock")
    probe = [{"SSH_AUTH_SOCK" => socket}, "ssh-add", "-T", File.join(@home, ".ssh/sfactory_ed25519.pub")]
    @fake_system.stub_command(probe, "agent refused operation", 1)
    step = create_step(Dotfiles::Step::SetupSSHKeysStep)
    step.run
    assert_equal original, @fake_system.read_file(ssh_config_path)
    refute step.complete?

    @fake_system.stub_command(probe, "", 0)
    step.run
    config = @fake_system.read_file(ssh_config_path)
    assert_includes config, "Host github.com\n  User git"
    assert_includes config, "IdentityFile ~/.ssh/sfactory_ed25519.pub\n"
    refute_includes config, "IdentityAgent none"
    assert step.complete?
  end

  def test_adds_notice_when_setup_needed
    step = create_step(Dotfiles::Step::SetupSSHKeysStep)
    step.run

    assert_equal 1, step.notices.length
    assert_includes step.notices.first[:title], "1Password"
  end

  def test_runs_for_non_admin_mac
    @fake_system.stub_macos
    @fake_system.stub_command(["groups"], "staff everyone")

    assert create_step(Dotfiles::Step::SetupSSHKeysStep).should_run?
  end

  def test_skips_in_ci_environment
    ENV["CI"] = "true"
    step = create_step(Dotfiles::Step::SetupSSHKeysStep)

    refute step.should_run?
    assert step.complete?
  ensure
    ENV.delete("CI")
  end
end
