# Dotfiles

Personal configuration files for my development environment.

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/nateberkopec/dotfiles.git ~/.dotfiles
   ```

2. Run the setup:
   ```bash
   cd ~/.dotfiles
   ./bin/dot run
   ```

   The script automatically detects your Ruby version and bootstraps a modern Ruby environment if needed.

   To see detailed output during installation:
   ```bash
   DEBUG=true ./bin/dot run
   ```

## Usage

```bash
dot <command>
```

**Commands:**
- `dot run` - Set up development environment from scratch
- `dot update` - Update dotfiles from the system
- `dot help` - Show help message

## How It Works: Steps

The setup process is organized into modular Steps. Each step is a Ruby class that inherits from the `Step` base class and implements a specific part of the setup process.

### Step Interface

Steps must implement these methods:

- `run` - Executes the setup action
- `complete?` - Returns true if the step has already been completed
- `update` (optional) - Syncs configuration from the system back to the dotfiles repo

Steps can also define:

- `self.depends_on` - Returns an array of step classes that must run first
- `should_run?` - Returns true if the step should execute (default: `!complete?`)

### Available Steps

For details on what each step does, see the implementations in `lib/step/`:

- `clone_dotfiles_step.rb`
- `configure_applications_step.rb`
- `configure_fish_step.rb`
- `disable_displays_have_spaces_step.rb`
- `install_applications_step.rb`
- `install_brew_packages_step.rb`
- `install_fonts_step.rb`
- `install_homebrew_step.rb`
- `install_oh_my_fish_step.rb`
- `set_fish_default_shell_step.rb`
- `set_font_smoothing_step.rb`
- `setup_ssh_keys_step.rb`
- `update_homebrew_step.rb`
- `update_macos_step.rb`
- `vscode_configuration_step.rb`

Steps are executed in dependency order, automatically sorted by their `depends_on` declarations.
