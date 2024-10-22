# Dotfiles

Personal configuration files for my development environment.

## Structure
```
.
├── fish/
│   ├── config.fish
│   └── functions/
├── iterm2/
│   └── com.googlecode.iterm2.plist
└── vscode/
    ├── settings.json
    ├── keybindings.json
    └── extensions.txt
```

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/dotfiles.git ~/.dotfiles
   ```

2. Run the setup script:
   ```bash
   ./setup.sh
   ```

## Manual Configuration

### iTerm2
- Import the preferences from `iterm2/com.googlecode.iterm2.plist`

### Fish Shell
- The Fish configuration will be automatically linked during setup
- Custom functions are stored in `fish/functions/`

### VSCode
- Settings and keybindings will be automatically linked
- Extensions will be automatically installed from the extensions.txt list
