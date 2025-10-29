require "test_helper"

class Dotfiles::UpdaterTest < Minitest::Test
  def setup
    @fake_system = FakeSystemAdapter.new
    @updater = Dotfiles::Updater.new
  end

  def test_initialize_sets_debug_from_env
    ENV["DEBUG"] = "true"
    updater = Dotfiles::Updater.new
    assert updater.instance_variable_get(:@debug)
  ensure
    ENV.delete("DEBUG")
  end

  def test_initialize_sets_debug_false_when_env_not_set
    ENV.delete("DEBUG")
    updater = Dotfiles::Updater.new
    refute updater.instance_variable_get(:@debug)
  end

  def test_initialize_creates_config
    config = @updater.instance_variable_get(:@config)
    assert_instance_of Dotfiles::Config, config
  end

  def test_run_calls_update_on_all_steps
    updated_steps = []
    step_class = Class.new(Dotfiles::Step) do
      define_method(:update) do
        updated_steps << self.class
      end
    end

    Dotfiles::Step.stub :all_steps, [step_class] do
      @updater.stub :commit_and_push_changes, nil do
        capture_io do
          @updater.run
        end
      end
    end

    assert_equal [step_class], updated_steps
  end

  def test_run_calls_commit_and_push_changes
    commit_called = false
    @updater.stub :commit_and_push_changes, -> { commit_called = true } do
      Dotfiles::Step.stub :all_steps, [] do
        @updater.run
      end
    end
    assert commit_called
  end

  def test_commit_and_push_changes_returns_when_no_changes
    config = @updater.instance_variable_get(:@config)
    config.stub :dotfiles_dir, "/tmp/dotfiles" do
      Dir.stub :chdir, nil do
        Open3.stub :capture3, ["", "", nil] do
          output = capture_io do
            @updater.send(:commit_and_push_changes)
          end
          assert_includes output.join, "No changes to commit"
        end
      end
    end
  end

  def test_commit_and_push_changes_adds_and_shows_diff_when_changes_exist
    config = @updater.instance_variable_get(:@config)
    git_add_called = false
    git_diff_called = false

    config.stub :dotfiles_dir, "/tmp/dotfiles" do
      Dir.stub :chdir, nil do
        Open3.stub :capture3, ["M file.txt\n", "", nil] do
          @updater.stub :system, ->(cmd) {
            git_add_called = true if cmd == "git add -A"
            git_diff_called = true if cmd == "git diff --cached --stat"
            !(cmd == "gum confirm 'Proceed with commit?'")
          } do
            capture_io do
              @updater.send(:commit_and_push_changes)
            end
          end
        end
      end
    end

    assert git_add_called
    assert git_diff_called
  end

  def test_commit_and_push_changes_returns_when_user_cancels
    config = @updater.instance_variable_get(:@config)
    config.stub :dotfiles_dir, "/tmp/dotfiles" do
      Dir.stub :chdir, nil do
        Open3.stub :capture3, ["M file.txt\n", "", nil] do
          @updater.stub :system, ->(cmd) {
            !(cmd == "gum confirm 'Proceed with commit?'")
          } do
            output = capture_io do
              @updater.send(:commit_and_push_changes)
            end
            assert_includes output.join, "Commit cancelled"
          end
        end
      end
    end
  end

  def test_commit_and_push_changes_tries_gc_ai_first
    config = @updater.instance_variable_get(:@config)
    gc_ai_called = false
    git_commit_called = false

    config.stub :dotfiles_dir, "/tmp/dotfiles" do
      Dir.stub :chdir, nil do
        Open3.stub :capture3, ["M file.txt\n", "", nil] do
          @updater.stub :system, ->(cmd) {
            gc_ai_called = true if cmd.include?("gc-ai")
            git_commit_called = true if cmd.include?("git commit") && !cmd.include?("gc-ai")
            if cmd == "gum confirm 'Proceed with commit?'"
            elsif cmd.include?("gc-ai")
            end
            true
          } do
            capture_io do
              @updater.send(:commit_and_push_changes)
            end
          end
        end
      end
    end

    assert gc_ai_called
    refute git_commit_called
  end

  def test_commit_and_push_changes_falls_back_to_git_commit_when_gc_ai_fails
    config = @updater.instance_variable_get(:@config)
    git_commit_called = false

    config.stub :dotfiles_dir, "/tmp/dotfiles" do
      Dir.stub :chdir, nil do
        Open3.stub :capture3, ["M file.txt\n", "", nil] do
          @updater.stub :system, ->(cmd) {
            if cmd == "gum confirm 'Proceed with commit?'"
              true
            elsif cmd.include?("gc-ai")
              false
            elsif cmd.include?("git commit")
              git_commit_called = true
              true
            else
              true
            end
          } do
            capture_io do
              @updater.send(:commit_and_push_changes)
            end
          end
        end
      end
    end

    assert git_commit_called
  end

  def test_commit_and_push_changes_uses_git_commit_flags_env_var
    ENV["GIT_COMMIT_FLAGS"] = "--amend --no-edit"
    config = @updater.instance_variable_get(:@config)
    correct_flags = false

    config.stub :dotfiles_dir, "/tmp/dotfiles" do
      Dir.stub :chdir, nil do
        Open3.stub :capture3, ["M file.txt\n", "", nil] do
          @updater.stub :system, ->(cmd) {
            if cmd == "gum confirm 'Proceed with commit?'"
            elsif cmd.include?("gc-ai --amend --no-edit")
              correct_flags = true
            end
            true
          } do
            capture_io do
              @updater.send(:commit_and_push_changes)
            end
          end
        end
      end
    end

    assert correct_flags
  ensure
    ENV.delete("GIT_COMMIT_FLAGS")
  end

  def test_command_exists_returns_true_for_existing_command
    @updater.stub :system, true do
      assert @updater.send(:command_exists?, "ls")
    end
  end

  def test_command_exists_returns_false_for_nonexistent_command
    @updater.stub :system, false do
      refute @updater.send(:command_exists?, "nonexistent_command_xyz")
    end
  end
end
