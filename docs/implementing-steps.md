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
  [Dotfiles::Step::InstallHomebrewStep, Dotfiles::Step::CloneDotfilesStep]
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

- `@config.packages` - Access `config/packages.yml`
- `@config.paths` - Access `config/paths.yml`

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
class Dotfiles::Step::ConfigureFishStep < Dotfiles::Step
  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep, Dotfiles::Step::CloneDotfilesStep]
  end

  def run
    debug "Setting up Fish configuration..."
    @system.mkdir_p(home_path("fish_config_dir"))
    @system.cp(dotfiles_source("fish_config"), home_path("fish_config_file"))
  end

  def complete?
    files_match?(dotfiles_source("fish_config"), home_path("fish_config_file"))
  end

  def update
    copy_if_exists(home_path("fish_config_file"), dotfiles_source("fish_config"))
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
class ConfigureFishStepTest < Minitest::Test
  def setup
    @system = FakeSystemAdapter.new
    @step = Dotfiles::Step::ConfigureFishStep.new(
      debug: false,
      dotfiles_repo: "https://github.com/user/dotfiles.git",
      dotfiles_dir: "/tmp/dotfiles",
      home: "/tmp/home",
      system: @system
    )
  end

  def test_complete_when_files_match
    @system.stub_file_content("/tmp/dotfiles/fish/config.fish", "content")
    @system.stub_file_content("/tmp/home/.config/fish/config.fish", "content")

    assert @step.complete?
  end
end
```

## Configuration Files

Steps often reference paths and packages from YAML config files:

### `config/paths.yml`

Maps logical names to file system paths:

```yaml
home_paths:
  fish_config_file: ~/.config/fish/config.fish
  fish_functions_dir: ~/.config/fish/functions

dotfiles_sources:
  fish_config: fish/config.fish
  fish_functions: fish/functions
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

1. **Idempotency**: Steps should be safe to run multiple times
2. **Atomic operations**: Each step should do one thing well
3. **Clear dependencies**: Use `depends_on` to express prerequisites
4. **Helpful debugging**: Use `debug()` to log what's happening
5. **User communication**: Use `add_notice()` for manual steps users need to complete
6. **CI-aware**: Check `ci_or_noninteractive?` for steps requiring user interaction
7. **Admin-aware**: Check `user_has_admin_rights?` for privileged operations
8. **Testable**: Use `@system` adapter instead of direct file operations
