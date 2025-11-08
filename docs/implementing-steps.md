# Implementing Steps

Steps are the building blocks of the dotfiles setup system. Each step handles a specific part of the configuration process, from installing Homebrew to configuring Fish shell.

## Step Anatomy

Every step is a Ruby class that inherits from `Dotfiles::Step` and must implement two core methods:

```ruby
class Dotfiles::Step::YourStep < Dotfiles::Step
  def run
    # Execute the setup action
  end

  def complete?
    # Return true if already done
  end
end
```

## Core Methods

### `run`

Executes the setup action. This method performs the actual work of configuring the system.

```ruby
def run
  debug "Installing something..."
  execute("some command")
end
```

### `complete?`

Returns `true` if the step has already been completed and doesn't need to run again. This makes the setup process idempotent.

```ruby
def complete?
  @system.file_exist?("/path/to/config")
end
```

### `update` (optional)

Syncs configuration from the system back into the dotfiles repository. Implement this to support the `dotf update` command.

```ruby
def update
  copy_if_exists(app_path("vscode_settings"), dotfiles_source("vscode_settings"))
end
```

## Class Methods

### `self.depends_on`

Declares dependencies on other steps. The system automatically runs steps in the correct order using topological sort.

```ruby
def self.depends_on
  # Example
  [Dotfiles::Step::InstallHomebrewStep]
end
```

### `self.display_name`

Customizes how the step name appears in output. Defaults to a formatted version of the class name.

```ruby
def self.display_name
  "VS Code Configuration"
end
```

### `should_run?`

Determines if the step should execute. Defaults to `!complete?` but can be overridden for conditional logic.

```ruby
def should_run?
  return false if ci_or_noninteractive?
  !complete?
end
```

## System Adapter

All file system and system interaction MUST go through lib/dotfiles/system_adapter.rb, which is exposed to steps as `@system`. Never use any methods that directly interact with the underlying system, such as `File`, `Dir`, `FileUtils`, `Kernel.system`, but not limited to these.

### Examples

```ruby
# ❌ WRONG - Direct file system access
def complete?
  File.exist?("/path/to/config")
end

# ✅ CORRECT - Use system adapter
def complete?
  @system.file_exist?("/path/to/config")
end
```

```ruby
# ❌ WRONG - Direct FileUtils usage
def run
  FileUtils.mkdir_p("/some/directory")
  FileUtils.cp("source", "dest")
end

# ✅ CORRECT - Use system adapter
def run
  @system.mkdir_p("/some/directory")
  @system.copy_file("source", "dest")
end
```

```ruby
# ❌ WRONG - Direct Dir usage
def complete?
  Dir.exist?("/Applications/Foo.app")
end

# ✅ CORRECT - Use system adapter
def complete?
  @system.dir_exist?("/Applications/Foo.app")
end
```

## Helper Methods

The `Step` base class provides many helpers for common operations. See [lib/dotfiles/step.rb](lib/dotfiles/step.rb). For reading config, see the Config class at [lib/dotfiles/config.rb](lib/dotfiles/config.rb).

## Example: Simple Step

```ruby
class Dotfiles::Step::InstallHomebrewStep < Dotfiles::Step
  def should_run?
    !command_exists?("brew")
  end

  def run
    debug "Installing Homebrew..."
    execute('/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"')
  end

  def complete?
    command_exists?("brew")
  end
end
```

For more examples, see the steps directory in lib.

## Step Registration

Steps are automatically registered when they inherit from `Dotfiles::Step`. The base class maintains a registry and handles dependency resolution.

No manual registration required - just create the class and it's available.

## Testing Steps

Steps should be tested with both unit tests and integration tests. Mock the `SystemAdapter` to avoid file system side effects:

```ruby
class SyncConfigDirectoryStepTest < Minitest::Test
  def setup
    @system = FakeSystemAdapter.new
    @step = Dotfiles::Step::SyncConfigDirectoryStep.new(
      debug: false,
      dotfiles_repo: "https://github.com/user/dotfiles.git",
      dotfiles_dir: "/tmp/dotfiles",
      home: "/tmp/home",
      system: @system
    )
  end

  def test_syncs_config_directory_items
    @system.stub_file_content("/tmp/dotfiles/files/config/fish/config.fish", "content")
    @step.run
    assert @system.file_exist?("/tmp/home/.config/fish/config.fish")
  end
end
```

## Best Practices

1. **Use the system adapter**: NEVER use methods that directly interact with the underlying system (such as `File`, `Dir`, `FileUtils`, `Kernel.system`, but not limited to these) - always use `@system`
2. **Idempotency**: Steps should be safe to run multiple times
3. **Atomic operations**: Each step should do one thing well
4. **Clear dependencies**: Use `depends_on` to express prerequisites
5. **Helpful debugging**: Use `debug()` to log what's happening
6. **User communication**: Use `add_notice()` for manual steps users need to complete
7. **CI-aware**: Check `ci_or_noninteractive?` for steps requiring user interaction
8. **Admin-aware**: Check `user_has_admin_rights?` for privileged operations
9. **Testable**: Design steps to work with `FakeSystemAdapter` in tests
