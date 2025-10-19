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
    @fake_system.stub_file_content(ssh_config_path, "Host github.com\n  User git\n")

    step = create_step(Dotfiles::Step::SetupSSHKeysStep)
    step.run

    config = @fake_system.read_file(ssh_config_path)
    assert_includes config, "Host github.com"
    assert_includes config, "IdentityAgent"
  end

  def test_adds_notice_when_setup_needed
    step = create_step(Dotfiles::Step::SetupSSHKeysStep)
    step.run

    assert_equal 1, step.notices.length
    assert_includes step.notices.first[:title], "1Password"
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
