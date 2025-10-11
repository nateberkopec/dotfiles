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

## What Gets Installed

- System updates via macOS Software Update
- Homebrew and essential packages
- Development tools: VSCode, Ghostty, Fish shell, Mise
- Applications: Arc, Aerospace, Raycast, 1Password
- Ruby (latest stable version)
- Oh My Fish and configurations
- Custom fonts

## Configuration

### Fish Shell
- Set as default shell with custom functions and configurations
- Oh My Fish installed with custom bundle

### VSCode
- Settings and keybindings automatically configured
- Extensions installed from extensions.txt

### Aerospace
- Tiling window manager configured with .aerospace.toml

### Git
- Global git configuration applied

### Ghostty
- Terminal configuration automatically installed
