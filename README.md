# Dotfiles

Personal configuration files for my development environment.

## Structure
```
.
├── amethyst/
│   └── com.amethyst.Amethyst.plist
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
└── fonts/
    └── *.ttf
```

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/nateberkopec/dotfiles.git ~/.dotfiles
   ```

2. Run the setup script:
   ```bash
   ./newenv.sh
   ```

   To see detailed output during installation:
   ```bash
   DEBUG=true ./newenv.sh
   ```

## What Gets Installed

- System updates via macOS Software Update
- Homebrew and essential packages
- Development tools: VSCode, Ghostty, Fish shell, Mise
- Applications: Arc, Amethyst, Raycast, 1Password
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

### Amethyst
- Window management preferences configured automatically

### Git
- Global git configuration applied

### Ghostty
- Terminal configuration automatically installed
