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

Syncs configuration from the system back into the dotfiles repository. Implement this to support the `dot update` command.

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

The `Step` base class provides many helpers for common operations:

### Execution

- `execute(command, quiet: true, sudo: false)` - Run shell commands with optional sudo
- `command_exists?(command)` - Check if a command is available
- `brew_quiet(command)` - Run Homebrew commands quietly

### File Operations

- `copy_if_exists(src, dest)` - Copy file only if source exists
- `files_match?(source, dest)` - Compare files by SHA256 hash
- `directories_match?(source, dest)` - Compare directory contents

### Path Helpers

- `home_path(key)` - Get home path from `config/paths.yml`
- `app_path(key)` - Get application path from `config/paths.yml`
- `dotfiles_source(key)` - Get dotfiles source path from `config/paths.yml`

### Configuration Access

See `config.rb` for more.

### System Checks

- `ci_or_noninteractive?` - Check if running in CI or non-interactive mode
- `user_has_admin_rights?` - Check if user has admin privileges

### User Communication

- `debug(message)` - Log debug messages (shown when `DEBUG=true`)
- `add_warning(title:, message:)` - Add warning to display after step completion
- `add_notice(title:, message:)` - Add notice to display after step completion

### macOS Defaults

- `defaults_read_equals?(command, expected_value)` - Check macOS defaults value

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

## Example: Step with Dependencies

```ruby
class Dotfiles::Step::InstallApplicationsStep < Dotfiles::Step
  def self.depends_on
    [Dotfiles::Step::InstallHomebrewStep]
  end

  def run
    debug "Installing applications..."
    @config.packages["applications"].each do |app|
      brew_quiet("install --cask #{app["brew_cask"]}")
    end
  end

  def complete?
    @config.packages["applications"].all? do |app|
      @system.dir_exist?(app["path"])
    end
  end
end
```

## Example: Step with File Syncing

```ruby
class Dotfiles::Step::SyncConfigDirectoryStep < Dotfiles::Step
  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep]
  end

  def run
    debug "Syncing config directory items..."
    config_items.each { |item| sync_item(item) }
  end

  def complete?
    config_items.all? { |item| item_synced?(item) }
  end

  def update
    config_items.each { |item| update_item(item) }
  end

  private

  def config_items
    @config.load_config("config_sync.yml").fetch("config_directory_items", [])
  end
end
```

## Example: Step with User Notices

```ruby
class Dotfiles::Step::SetupSSHKeysStep < Dotfiles::Step
  def run
    @system.write_file(SSH_CONFIG_PATH, ssh_config_content)

    add_notice(
      title: "ℹ️  1Password SSH Agent Setup Required",
      message: "To complete SSH setup:\n1. Open 1Password app\n2. Go to Settings → Developer\n3. Enable 'Use the SSH agent'"
    )
  end

  def complete?
    @system.file_exist?(SSH_CONFIG_PATH) &&
      @system.read_file(SSH_CONFIG_PATH).include?("IdentityAgent")
  end
end
```

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

## Configuration Files

Steps often reference paths and packages from YAML config files:

### `config/paths.yml`

Maps logical names to file system paths:

```yaml
home_paths:
  gitconfig: ~/.gitconfig
  aerospace_config: ~/.aerospace.toml

dotfiles_sources:
  git_config: files/git/.gitconfig
  aerospace_config: files/aerospace/.aerospace.toml
```

### `config/config_sync.yml`

Defines config directory items to sync (files and directories ending in /):

```yaml
config_directory_items:
  - fish/
  - omf/
```

### `config/packages.yml`

Defines packages and applications to install:

```yaml
applications:
  - name: "Visual Studio Code"
    brew_cask: "visual-studio-code"
    path: "/Applications/Visual Studio Code.app"
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
