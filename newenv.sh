#!/bin/bash

# Exit on error
set -e

echo "Starting macOS development environment setup..."

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "Homebrew already installed, updating..."
    brew update
fi
# Clone dotfiles repo (replace URL with your actual dotfiles repo)
DOTFILES_REPO="https://github.com/nateberkopec/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

if [ ! -d "$DOTFILES_DIR" ]; then
    echo "Cloning dotfiles repository..."
    git clone $DOTFILES_REPO $DOTFILES_DIR
else
    echo "Dotfiles directory already exists, pulling latest changes..."
    cd $DOTFILES_DIR
    git pull
fi

# Combine brew install commands
brew install zoxide ghostty bat gh rust mise direnv fish orbstack fontconfig libyaml

# Install cask applications
brew install --cask amethyst github visual-studio-code alfred 1password 1password/tap/1password-cli

mkdir -p $HOME/Library/Application\ Support/com.mitchellh.ghostty/
cp $DOTFILES_DIR/ghostty/config $HOME/Library/Application\ Support/com.mitchellh.ghostty

# Install Arc browser if not already installed
if [ ! -d "/Applications/Arc.app" ]; then
    echo "Installing Arc browser..."
    brew install --cask arc
else
    echo "Arc browser is already installed, skipping..."
fi

echo "Configuring Amethyst..."
cp $DOTFILES_DIR/amethyst/com.amethyst.Amethyst.plist  ~/Library/Preferences/

# Copy Git global configuration
echo "Configuring Git global settings..."
cp $DOTFILES_DIR/git/.gitconfig ~/.gitconfig

# Copy VSCode settings
echo "Configuring VSCode..."
mkdir -p ~/Library/Application\ Support/Code/User
cp $DOTFILES_DIR/vscode/settings.json ~/Library/Application\ Support/Code/User/
cp $DOTFILES_DIR/vscode/keybindings.json ~/Library/Application\ Support/Code/User/

# Install VSCode extensions from file if it exists
if [ -f "$DOTFILES_DIR/vscode/extensions.txt" ]; then
    echo "Installing VSCode extensions..."
    while IFS= read -r extension; do
        code --install-extension "$extension"
    done < "$DOTFILES_DIR/vscode/extensions.txt"
fi

echo "Configuring Alfred..."
cp $DOTFILES_DIR/alfred/*  ~/Library/Preferences/

echo "Installing latest stable Ruby..."
mise use --global ruby@latest
mise install ruby@latest

# Change default shell to Fish
FISH_PATH=$(which fish)
if ! grep -q $FISH_PATH /etc/shells; then
    echo "Adding Fish to allowed shells..."
    echo $FISH_PATH | sudo tee -a /etc/shells
fi

# Change default shell to Fish only if it's not already the default
if ! dscl . -read ~/ UserShell | grep -q "$FISH_PATH"; then
    echo "Changing default shell to Fish..."
    chsh -s "$FISH_PATH"
else
    echo "Fish is already the default shell, skipping..."
fi

# Copy Fish config
echo "Setting up Fish configuration..."
mkdir -p ~/.config/fish
cp $DOTFILES_DIR/fish/config.fish ~/.config/fish/
cp -R $DOTFILES_DIR/fish/functions ~/.config/fish/ 2>/dev/null || true

# Install oh-my-fish if not present
if [ ! -d "$HOME/.local/share/omf" ]; then
    echo "Installing oh-my-fish..."
    curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install > install
    fish -c "fish install --noninteractive"
    rm install
else
    echo "oh-my-fish already installed, skipping..."
fi

# Set up omf configuration
echo "Configuring oh-my-fish..."
mkdir -p ~/.config/omf
cp -r "$DOTFILES_DIR/omf/"* ~/.config/omf/

# Install the theme and plugins from bundle
fish -c "omf install"

# Open/install fonts only if they are not already installed
for font in ~/.dotfiles/fonts/*.{ttf}; do
    font_name=$(basename "$font")
    if ! fc-list | grep -q "$font_name"; then
        echo "Installing font: $font_name"
        open "$font"
    else
        echo "Font $font_name is already installed, skipping..."
    fi
done

echo "Installation complete! Please restart your terminal for all changes to take effect."
