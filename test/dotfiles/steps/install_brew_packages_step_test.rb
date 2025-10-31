require "test_helper"

class InstallBrewPackagesStepTest < Minitest::Test
  def setup
    super
    @step = create_step(Dotfiles::Step::InstallBrewPackagesStep)
    stub_brew_config
  end

  def stub_brew_config
    @step.config.packages = {
      "brew" => {
        "packages" => ["git", "fish", "tmux"],
        "casks" => ["firefox", "iterm2"]
      }
    }
  end

  def test_should_run_returns_false_by_default
    @fake_system.stub_file_content(File.join(@dotfiles_dir, "Brewfile"), "")
    @fake_system.stub_execute_result(
      "brew bundle check --file=#{File.join(@dotfiles_dir, "Brewfile")} --no-upgrade >/dev/null 2>&1",
      ["", 0]
    )
    refute @step.should_run?
  end

  def test_complete_returns_false_by_default
    refute @step.complete?
  end

  def test_packages_already_installed_returns_true_when_all_installed
    brewfile_path = File.join(@dotfiles_dir, "Brewfile")
    @fake_system.stub_execute_result(
      "brew bundle check --file=#{brewfile_path} --no-upgrade >/dev/null 2>&1",
      ["", 0]
    )

    assert @step.packages_already_installed?
  end

  def test_packages_already_installed_returns_false_when_not_installed
    brewfile_path = File.join(@dotfiles_dir, "Brewfile")
    @fake_system.stub_execute_result(
      "brew bundle check --file=#{brewfile_path} --no-upgrade >/dev/null 2>&1",
      ["error", 1]
    )

    refute @step.packages_already_installed?
  end

  def test_packages_already_installed_caches_result
    brewfile_path = File.join(@dotfiles_dir, "Brewfile")
    @fake_system.stub_execute_result(
      "brew bundle check --file=#{brewfile_path} --no-upgrade >/dev/null 2>&1",
      ["", 0]
    )

    @step.packages_already_installed?
    @step.packages_already_installed?

    assert_equal 1, @fake_system.operation_count(:execute)
  end

  def test_should_run_returns_false_when_packages_installed
    brewfile_path = File.join(@dotfiles_dir, "Brewfile")
    @fake_system.stub_execute_result(
      "brew bundle check --file=#{brewfile_path} --no-upgrade >/dev/null 2>&1",
      ["", 0]
    )

    refute @step.should_run?
  end

  def test_should_run_returns_true_when_packages_not_installed
    brewfile_path = File.join(@dotfiles_dir, "Brewfile")
    @fake_system.stub_execute_result(
      "brew bundle check --file=#{brewfile_path} --no-upgrade >/dev/null 2>&1",
      ["error", 1]
    )

    assert @step.should_run?
  end

  def test_should_run_generates_brewfile
    brewfile_path = File.join(@dotfiles_dir, "Brewfile")
    @fake_system.stub_execute_result(
      "brew bundle check --file=#{brewfile_path} --no-upgrade >/dev/null 2>&1",
      ["", 0]
    )

    @step.should_run?

    assert @fake_system.file_exist?(brewfile_path)
  end

  def test_generate_brewfile_creates_file_with_packages
    @step.send(:generate_brewfile)
    brewfile_path = File.join(@dotfiles_dir, "Brewfile")

    content = @fake_system.read_file(brewfile_path)
    assert_includes content, 'brew "git"'
    assert_includes content, 'brew "fish"'
    assert_includes content, 'brew "tmux"'
  end

  def test_generate_brewfile_creates_file_with_casks
    @step.send(:generate_brewfile)
    brewfile_path = File.join(@dotfiles_dir, "Brewfile")

    content = @fake_system.read_file(brewfile_path)
    assert_includes content, 'cask "firefox"'
    assert_includes content, 'cask "iterm2"'
  end

  def test_generate_brewfile_handles_empty_packages
    @step.config.packages = {"brew" => {"packages" => [], "casks" => []}}
    @step.send(:generate_brewfile)
    brewfile_path = File.join(@dotfiles_dir, "Brewfile")

    content = @fake_system.read_file(brewfile_path)
    assert_equal "\n", content
  end

  def test_generate_brewfile_handles_missing_brew_config
    @step.config.packages = {}
    @step.send(:generate_brewfile)
    brewfile_path = File.join(@dotfiles_dir, "Brewfile")

    content = @fake_system.read_file(brewfile_path)
    assert_equal "\n", content
  end

  def test_install_packages_uses_appdir_when_no_admin_rights
    @step.stub :user_has_admin_rights?, false do
      brewfile_path = File.join(@dotfiles_dir, "Brewfile")
      expected_cmd = "HOMEBREW_CASK_OPTS=\"--appdir=~/Applications\" brew bundle install --file=#{brewfile_path} 2>&1"
      @fake_system.stub_execute_result(expected_cmd, ["success", 0])

      @step.install_packages

      assert @fake_system.received_operation?(:execute, expected_cmd, {quiet: true})
    end
  end

  def test_install_packages_uses_default_appdir_when_admin
    @step.stub :user_has_admin_rights?, true do
      brewfile_path = File.join(@dotfiles_dir, "Brewfile")
      expected_cmd = "HOMEBREW_CASK_OPTS=\"\" brew bundle install --file=#{brewfile_path} 2>&1"
      @fake_system.stub_execute_result(expected_cmd, ["success", 0])

      @step.install_packages

      assert @fake_system.received_operation?(:execute, expected_cmd, {quiet: true})
    end
  end

  def test_check_skipped_packages_adds_warning_when_packages_skipped
    @fake_system.stub_execute_result("brew list --formula 2>/dev/null", ["git\nfish", 0])
    @fake_system.stub_execute_result("brew list --cask 2>/dev/null", ["firefox", 0])

    @step.check_skipped_packages

    assert_equal 1, @step.warnings.length
    assert_equal "⚠️  Homebrew Installation Skipped", @step.warnings.first[:title]
    assert_includes @step.warnings.first[:message], "tmux"
    assert_includes @step.warnings.first[:message], "iterm2"
  end

  def test_check_skipped_packages_no_warning_when_all_installed
    @fake_system.stub_execute_result("brew list --formula 2>/dev/null", ["git\nfish\ntmux", 0])
    @fake_system.stub_execute_result("brew list --cask 2>/dev/null", ["firefox\niterm2", 0])

    @step.check_skipped_packages

    assert_equal 0, @step.warnings.length
  end

  def test_run_installs_packages
    brewfile_path = File.join(@dotfiles_dir, "Brewfile")
    install_cmd = "HOMEBREW_CASK_OPTS=\"\" brew bundle install --file=#{brewfile_path} 2>&1"
    @fake_system.stub_execute_result(install_cmd, ["success", 0])
    @fake_system.stub_execute_result("brew list --formula 2>/dev/null", ["git\nfish\ntmux", 0])
    @fake_system.stub_execute_result("brew list --cask 2>/dev/null", ["firefox\niterm2", 0])

    @step.stub :user_has_admin_rights?, true do
      @step.run
    end

    assert @fake_system.received_operation?(:execute, install_cmd, {quiet: true})
  end

  def test_run_checks_skipped_packages
    brewfile_path = File.join(@dotfiles_dir, "Brewfile")
    install_cmd = "HOMEBREW_CASK_OPTS=\"\" brew bundle install --file=#{brewfile_path} 2>&1"
    @fake_system.stub_execute_result(install_cmd, ["success", 0])
    @fake_system.stub_execute_result("brew list --formula 2>/dev/null", ["git", 0])
    @fake_system.stub_execute_result("brew list --cask 2>/dev/null", ["", 0])

    @step.stub :user_has_admin_rights?, true do
      @step.run
    end

    assert @fake_system.received_operation?(:execute, "brew list --formula 2>/dev/null", {quiet: true})
    assert @fake_system.received_operation?(:execute, "brew list --cask 2>/dev/null", {quiet: true})
  end

  def test_complete_returns_true_when_ran
    @step.instance_variable_set(:@ran, true)
    assert @step.complete?
  end

  def test_complete_returns_false_when_brewfile_missing
    refute @step.complete?
  end

  def test_complete_raises_when_packages_installed_status_not_checked
    brewfile_path = File.join(@dotfiles_dir, "Brewfile")
    @fake_system.stub_file_content(brewfile_path, "content")

    error = assert_raises(RuntimeError) do
      @step.complete?
    end
    assert_includes error.message, "packages_already_installed? must be called before complete?"
  end

  def test_complete_returns_packages_installed_status_when_checked
    brewfile_path = File.join(@dotfiles_dir, "Brewfile")
    @fake_system.stub_file_content(brewfile_path, "content")
    @fake_system.stub_execute_result(
      "brew bundle check --file=#{brewfile_path} --no-upgrade >/dev/null 2>&1",
      ["", 0]
    )

    @step.packages_already_installed?
    assert @step.complete?
  end

  def test_update_does_nothing
    @step.update
  end
end
