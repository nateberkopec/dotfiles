# Dotfiles

Personal configuration files for my development environment.

## Structure
```
.
├── bin/
│   └── setup                    # Main setup script (recommended)
├── aerospace/
│   └── .aerospace.toml
├── fish/
│   ├── config.fish
│   └── functions/
├── ghostty/
│   └── config
├── git/
│   └── .gitconfig
├── omf/
│   └── bundle
├── vscode/
│   ├── settings.json
│   ├── keybindings.json
│   └── extensions.txt
├── fonts/
│   └── *.ttf
└── newenv.rb                    # Ruby setup script
```

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/nateberkopec/dotfiles.git ~/.dotfiles
   ```

2. Run the setup script (recommended):
   ```bash
   cd ~/.dotfiles
   ./bin/setup
   ```

   The setup script automatically detects your Ruby version and bootstraps a modern Ruby environment if needed.

   To see detailed output during installation:
   ```bash
   DEBUG=true ./bin/setup
   ```

### Alternative Setup Methods

For advanced users, you can run the setup scripts directly:

**Bash version:**
```bash
./newenv.sh
```

**Ruby version (requires Ruby >= 3.4):**
```ruby
ruby newenv.rb
```

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
