#!/bin/bash

# Exit on error
set -e

# Debug function
debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo "$1"
    fi
}

# Homebrew install function
brew_quiet() {
    if [ "${DEBUG:-false}" = "true" ]; then
        brew "$@"
    else
        brew "$@" >/dev/null
    fi
}

# Software update function
softwareupdate_quiet() {
    if [ "${DEBUG:-false}" = "true" ]; then
        sudo softwareupdate -i -a
    else
        sudo softwareupdate -i -a >/dev/null 2>&1
    fi
}

debug "Starting macOS development environment setup..."

debug "Checking for macOS updates..."
softwareupdate_quiet

defaults -currentHost write -g AppleFontSmoothing -int 0

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    debug "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    debug "Homebrew already installed, updating..."
    brew_quiet update
fi
# Clone dotfiles repo (replace URL with your actual dotfiles repo)
DOTFILES_REPO="https://github.com/nateberkopec/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

if [ ! -d "$DOTFILES_DIR" ]; then
    debug "Cloning dotfiles repository..."
    git clone $DOTFILES_REPO $DOTFILES_DIR
else
    debug "Dotfiles directory already exists, pulling latest changes..."
    cd $DOTFILES_DIR
    git pull
fi

# Combine brew install commands
brew_quiet install zoxide ghostty bat gh rust mise direnv fish orbstack fontconfig libyaml coreutils

# Install cask applications
brew_quiet install --cask amethyst github visual-studio-code raycast

# Install 1Password if not already installed
if [ ! -d "/Applications/1Password.app" ]; then
    debug "Installing 1Password..."
    brew_quiet install --cask 1password 1password/tap/1password-cli
else
    debug "1Password is already installed, skipping..."
fi

mkdir -p $HOME/Library/Application\ Support/com.mitchellh.ghostty/
cp $DOTFILES_DIR/ghostty/config $HOME/Library/Application\ Support/com.mitchellh.ghostty

# Install Arc browser if not already installed
if [ ! -d "/Applications/Arc.app" ]; then
    debug "Installing Arc browser..."
    brew_quiet install --cask arc
else
    debug "Arc browser is already installed, skipping..."
fi

debug "Configuring Amethyst..."
cp $DOTFILES_DIR/amethyst/com.amethyst.Amethyst.plist  ~/Library/Preferences/

# Copy Git global configuration
debug "Configuring Git global settings..."
cp $DOTFILES_DIR/git/.gitconfig ~/.gitconfig

# Copy VSCode settings
debug "Configuring VSCode..."
mkdir -p ~/Library/Application\ Support/Code/User
cp $DOTFILES_DIR/vscode/settings.json ~/Library/Application\ Support/Code/User/
cp $DOTFILES_DIR/vscode/keybindings.json ~/Library/Application\ Support/Code/User/

# Install VSCode extensions from file if it exists
if [ -f "$DOTFILES_DIR/vscode/extensions.txt" ]; then
    debug "Installing VSCode extensions..."
    installed_extensions=$(code --list-extensions)
    while IFS= read -r extension; do
        if ! echo "$installed_extensions" | grep -q "^${extension}$"; then
            debug "Installing VSCode extension: $extension"
            code --install-extension "$extension"
        else
            debug "VSCode extension already installed: $extension"
        fi
    done < "$DOTFILES_DIR/vscode/extensions.txt"
fi

debug "Installing latest stable Ruby..."
mise use --global ruby@latest
mise install ruby@latest

# Change default shell to Fish
FISH_PATH=$(which fish)
if ! grep -q $FISH_PATH /etc/shells; then
    debug "Adding Fish to allowed shells..."
    echo $FISH_PATH | sudo tee -a /etc/shells
fi

# Change default shell to Fish only if it's not already the default
if ! dscl . -read ~/ UserShell | grep -q "$FISH_PATH"; then
    debug "Changing default shell to Fish..."
    chsh -s "$FISH_PATH"
else
    debug "Fish is already the default shell, skipping..."
fi

# Copy Fish config
debug "Setting up Fish configuration..."
mkdir -p ~/.config/fish
cp $DOTFILES_DIR/fish/config.fish ~/.config/fish/
cp -R $DOTFILES_DIR/fish/functions ~/.config/fish/ 2>/dev/null || true

# Install oh-my-fish if not present
if [ ! -d "$HOME/.local/share/omf" ]; then
    debug "Installing oh-my-fish..."
    curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install > install
    fish -c "fish install --noninteractive"
    rm install
else
    debug "oh-my-fish already installed, skipping..."
fi

# Set up omf configuration
debug "Configuring oh-my-fish..."
mkdir -p ~/.config/omf
cp -r "$DOTFILES_DIR/omf/"* ~/.config/omf/

# Install the theme and plugins from bundle
fish -c "omf install"

# Open/install fonts only if they are not already installed
for font in ~/.dotfiles/fonts/*.ttf; do
    font_name=$(basename "$font")
    if ! fc-list | grep -q "$font_name"; then
        debug "Installing font: $font_name"
        open "$font"
    else
        debug "Font $font_name is already installed, skipping..."
    fi
done

echo "Installation complete! Please restart your terminal for all changes to take effect."
